# Serverless Constraints — the full reasoning

This file explains _why_ each standard pattern breaks on Vercel functions, with enough
depth that you can reason about novel cases the table in SKILL.md doesn't list.

## The execution model

A Vercel function (Next.js route handler, server action, API route) is:

- **Autoscaled & many-instanced.** There is no "the server" — there are many instances,
  and which one serves a given request is non-deterministic. Nothing in one instance's
  memory is visible to another.
- **Cold-started.** A new instance pays init cost (module load, client construction, TLS
  handshake to the DB). Any in-memory cache or counter starts empty.
- **Reclaimable.** An idle instance is eventually torn down, taking its memory with it.

### Fluid Compute changes the within-instance details

Vercel **Fluid Compute** (default on new projects) softens the old "one request per
instance, no shared memory, frozen after response" picture:

- **One instance can serve multiple concurrent invocations** — so module-level memory is
  shared across those concurrent in-flight requests (a source of subtle cross-request bugs
  if you stash per-request state in module scope).
- **Module memory persists across invocations** on a warm instance — so an in-memory
  cache/counter/breaker can survive and be reused **within that instance**.
- **Background work via `after()`/`waitUntil`** is supported (still bounded by the function
  lifetime), rather than reliably dropped.

What Fluid Compute does **not** change: there are still **many** instances, so nothing in
module memory is fleet-wide. Per-instance state is fine for best-effort optimization or
per-instance debugging; it is never a system of record or aggregate protection. And Fluid's
per-instance concurrency **multiplies** outbound resource pressure (DB connections), which
matters for pool sizing.

### The Edge runtime is separate and more restricted

`runtime = "edge"` (and any code you pin to it) is a V8-isolate environment: no Node APIs,
no TCP sockets to Postgres, strict CPU/time limits. **DB drivers and most Node libraries do
not run there.** Note: Next.js **`proxy.ts` (middleware) now defaults to the Node.js
runtime**, so middleware is not _necessarily_ Edge anymore — but it still runs _before_ the
route handler and so can't observe the handler's downstream timings (see below).

## Why in-process metrics are wrong here

Prometheus uses a _pull_ model: a scraper periodically GETs `/metrics` from a known,
stable target and reads cumulative counters. On serverless:

- There is no stable target — the scraper reaches an arbitrary instance among many.
- Counters are per-instance; even with Fluid Compute reuse, one instance's counters never
  represent the fleet, and a cold start resets them.
- An idle period can reclaim the instance holding all your counts.

So a web `/api/metrics` endpoint backed by `prom-client` returns numbers that are, at best,
"whatever this one instance happened to count since it woke up" — not fleet truth. It looks
like it works (200, valid exposition format) which is exactly why it's dangerous. (It's fine
as a deliberately-labeled, locked-down, single-instance debug surface — just never as your
system of record.)

**Correct approaches** (all _push_, so they don't depend on a stable process):

- **Sentry** spans + `measurements`/metrics — already sampled, already aggregated server-side.
- **OpenTelemetry** with an OTLP exporter to a collector (the collector is the long-lived
  aggregator; the function just emits).
- **Vercel's own observability** for route-level RED metrics (rate, errors, duration).
- **Structured logs → a log aggregator** (Datadog, Axiom, Logtail) with metric extraction.

Pull-Prometheus is correct **only for a long-lived companion process** you control — a
Temporal/Inngest worker, a daemon, a container. Those _do_ stay alive and _can_ be scraped.

## Why in-memory circuit breakers can't protect the fleet

A breaker tracks recent failures and "opens" to stop calling a failing upstream. Aggregate
protection requires _fleet-wide, shared_ state. A module-scope breaker only sees one
instance's failures — under Fluid Compute it may persist across that instance's invocations,
but it still can't aggregate across the many instances, so:

- 100 instances each see 1 failure → no instance trips, but the upstream took 100 hits.
- An instance that _did_ trip is reclaimed → its breaker resets, traffic floods back.

The breaker provides a false sense of _fleet_ protection (it can still locally short-circuit
a hammered instance, which is a minor benefit). **On web paths, prefer:**

- **Tight timeouts** so a slow upstream fails fast instead of stalling the function.
- **Graceful degradation** so the failure is contained (serve stale/partial/empty).
- **Idempotent, bounded retries** only where safe (and ideally only in a worker).

If you genuinely need aggregate breaking (e.g. to protect a fragile upstream), the state
must be **shared**: a Redis/Upstash counter, or a small Postgres table the instances read
and write. That's real work and real latency — justify it before adopting it. Better: move
the fragile call into a **durable worker** where a normal in-memory breaker is valid and a
workflow engine already gives you retry/backoff.

## Background work after response — use `after()`/`waitUntil`, but keep it short

A tempting pattern: respond to the user, then "fire and forget" some logging/cleanup/
webhook. Don't schedule it as a bare floating promise — use **`after()` (Next.js) /
`waitUntil()` (Vercel)**, the supported way to extend execution past the response. It's
still **bounded by the function lifetime**, so it's only for _short_ post-response side
effects (analytics, a webhook ping). Anything heavier (image processing, multi-step
orchestration, long polling) belongs in a **queue/workflow engine**, not the request
lifecycle.

## Why middleware can't own resilience

Whether `proxy.ts` runs on Node (now the default) or Edge, it runs **before** the route
handler and hands off — so it fundamentally can't wrap or observe the handler's internal
DB/upstream timings. (If pinned to the Edge runtime it additionally can't open a Postgres
connection at all — no TCP.)

Use middleware for what it's good at: auth gating, redirects, header injection, request-id
stamping, light rewrites. Put all timeout/timing/breaker/DB-access logic in the **route
handler or service layer**, where it can actually see and bound the work.

## Why the default timeout is not a budget

Vercel functions have a maximum duration, configurable per route via `maxDuration`. The
exact defaults and caps are **version- and plan-dependent and have grown substantially**
(Fluid Compute raised them well past the old serverless numbers — into the hundreds of
seconds) — **verify your project's current limits rather than trusting a remembered
number.** Whatever it is, the platform max is a **ceiling, not a budget**: a request blocked
on a hung dependency sits there consuming the whole window, holding a DB connection, until
it's killed. That's how one slow dependency cascades into pool exhaustion and a site-wide
stall — and a _larger_ ceiling makes this worse, not better, because the stall lasts longer.

**Set explicit budgets that fail _before_ the ceiling:**

```ts
// app/api/some-route/route.ts
export const runtime = 'nodejs' // not edge — needs DB/Node
export const maxDuration = 15 // hard ceiling for THIS route
export const dynamic = 'force-dynamic' // don't cache a dynamic data route
```

with dependency timeouts (DB statement timeout, `AbortSignal.timeout()` on fetch) set
_below_ `maxDuration`, so the order of failure is: dependency timeout → typed error →
controlled degraded response, all comfortably inside the function ceiling.

## Cold starts and connection storms

Each cold instance opens a fresh DB connection (and TLS handshake). A traffic spike that
spawns many instances creates a **connection storm** against the database. This is _the_
reason to (a) use a transaction pooler in front of Postgres and (b) keep each instance's
pool tiny. See `database-postgres.md`.

## A decision rule for any new proposal

When someone proposes an infra/observability mechanism, run it through:

1. **Does it need a process that stays alive?** (timers, in-memory accumulation, scrape
   target, warm cache as source of truth) → rework for serverless or move to a worker.
2. **Does it need state shared across concurrent instances?** (breakers, rate limits,
   dedup, locks) → it needs a shared store, not module memory.
3. **Does it run on the edge?** (middleware) → no DB, no Node APIs, no heavy state.
4. **Does it bound a hang at a known point below the function ceiling?** → if not, add an
   explicit budget.

If a proposal clears all four, it's probably serverless-safe.
