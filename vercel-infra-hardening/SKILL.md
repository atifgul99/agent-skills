---
name: vercel-infra-hardening
description: >-
  Production observability and infrastructure-hardening playbook for Vercel
  serverless apps (Next.js / Node functions) backed by managed Postgres
  (Supabase, Neon, RDS Proxy) and external APIs. Use this whenever the user is
  hardening, auditing, or productionizing a Vercel-hosted app — including health
  checks, readiness probes, metrics, Sentry/OpenTelemetry tracing, database
  connection pooling and statement timeouts, request latency budgets, circuit
  breakers, retries, graceful degradation, caching strategy, React Query
  adoption, SLOs, alerts, dashboards, or runbooks. Also use when diagnosing slow
  pages, hung requests, "the app got slow until we restarted it", connection-pool
  exhaustion, cross-region database latency, or when someone proposes a standard
  observability tool (prom-client, an in-memory circuit breaker, a long-lived
  metrics process) that may not survive an ephemeral serverless runtime. Reach
  for this even when the user only says "make this production-ready", "harden
  our infra", "add monitoring", or "why is this so slow" without naming Vercel
  explicitly, as long as the deployment target is serverless.
---

# Vercel Infrastructure Hardening & Observability

A reusable playbook for making serverless apps on Vercel genuinely production-grade.
It exists because **most "industry-standard" observability and resilience tooling
assumes a long-lived server process** — a single box you can scrape, hold state in,
and keep warm. Vercel functions are not that: they are autoscaled, may cold-start,
and have no stable cross-instance memory. Patterns that are correct on a Kubernetes pod
are quietly wrong on a serverless function, and they fail _silently_ — the metrics
endpoint returns 200, the breaker compiles, the timeout is "set" — they just don't do
what you think.

This skill helps you (1) recognize which standard patterns break, (2) substitute the
serverless-correct equivalent, and (3) run a structured hardening audit on any project.

## The one idea to internalize

> On a long-lived server, the _process_ is the unit of state and observation.
> On serverless, the only thing you can rely on across the fleet is an _external,
> shared_ store — local memory is, at best, per-instance and best-effort.

When you evaluate any infra/observability proposal, ask: **"Does this depend on a
process that stays alive, or on state shared across concurrent instances?"** If yes, it
needs an external/shared mechanism, not module memory.

## Fluid Compute changes the details (verify your runtime)

Vercel **Fluid Compute** (now the default for new projects) changes the naive
"one request per ephemeral instance, no shared memory" mental model: **one instance can
serve multiple concurrent invocations**, module-level memory **can persist** across
invocations on a warm instance, and **function durations are much higher** than the old
serverless defaults. This does **not** rescue the broken patterns below — they still fail
as a _system of record_ or _aggregate protection_ — but it does make the reasoning more
nuanced:

- In-memory counters/breakers/caches may persist across invocations **on one instance**,
  so they're usable for per-instance debugging or best-effort optimization — but never as
  fleet-wide truth or protection (there are still many instances).
- Per-instance concurrency **multiplies** DB connection pressure: total client connections
  ≈ instances × per-instance concurrency × pool `max`. This makes small pools more
  important, not less (see DB section).
- Timeout ceilings are large and version-dependent — **do not hard-code numbers; check
  your project's current function limits.**

Treat every specific limit in this skill as "verify against current Vercel/Next.js/your
pooler docs," not gospel. The _shapes_ are durable; the _numbers and runtime defaults_
drift.

## What breaks on serverless (and the fix)

| Standard pattern                                                       | Why it's wrong on serverless                                                                                                                                                                               | Serverless-correct fix                                                                                                                                                                                                                                                                                                            |
| ---------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **In-process Prometheus + `/metrics` scrape** (prom-client)            | A scrape hits one arbitrary instance; its counters reset on cold start and (even with Fluid Compute reuse) reflect only that instance, never the fleet. Not a valid system of record.                      | **Push/export telemetry**: Sentry spans + measurements, OpenTelemetry → OTLP collector/Vercel Trace Drain, Vercel's built-in observability. Pull-Prometheus only for a _long-lived_ worker/daemon. A web `/api/metrics` is acceptable only as a labeled, non-aggregated, internal debug surface.                                  |
| **In-memory circuit breaker** (`opossum` in a module var)              | State is per-instance — under Fluid Compute it may persist on a warm instance, but it's still not shared across the fleet, so it can't trip reliably or protect the upstream in aggregate.                 | **Bounded timeouts + fast-fail + graceful degradation** on web. For real aggregate breaking, use a shared store (Redis/Upstash/a Postgres row). Put stateful breakers in a long-lived worker, where module memory is valid.                                                                                                       |
| **Session-level `SET statement_timeout`** through a transaction pooler | In transaction-pooling mode a separate `SET` may not apply to the next pooled transaction (connections are reused across clients).                                                                         | Make it durable: prefer **`ALTER ROLE <dedicated app role> SET statement_timeout`**; use **`SET LOCAL`** only inside an explicit transaction; use connection-string `options=-c statement_timeout=...` **only after verifying your specific pooler forwards it**. Plus an app-level `AbortSignal.timeout()` race.                 |
| **Large per-instance connection pool** (`max: 20`)                     | total connections ≈ instances × per-instance concurrency (Fluid) × `max`. A spike exhausts the ceiling — the classic "site got slow until we restarted" incident.                                          | **Default `max: 1`** for typical request/response traffic (Supabase/serverless guidance: often 1 is optimal); scale up only from **measured** concurrency and real pooler headroom. Always set `idle_timeout`, `max_lifetime`, `connect_timeout`. Prefer Vercel's `attachDatabasePool` for supported clients under Fluid Compute. |
| **Resilience/timing logic in middleware (`proxy.ts`)**                 | Middleware runs **before** the route handler and hands off — it cannot observe or interrupt the handler's downstream DB/upstream timings. (On the Edge runtime it also can't open a DB connection at all.) | Put timeouts, timing, breakers, DB access in **route handlers / services**. Use middleware for auth/routing/headers/request-id stamping. (Note: Next.js `proxy.ts` now defaults to the **Node.js** runtime — "middleware is always Edge" is outdated.)                                                                            |
| **Long-lived background timers / cron in the app** (`setInterval`)     | Instances aren't guaranteed warm; timers don't fire reliably and work scheduled "after response" can be dropped.                                                                                           | Use **Vercel Cron**, a durable workflow engine (Temporal/Inngest/QStash), or an external scheduler. Use `after()`/`waitUntil` only for short post-response side effects (still bounded by the function lifetime).                                                                                                                 |
| **In-memory cache as source of truth**                                 | Per-instance and best-effort even under Fluid Compute; inconsistent across the fleet.                                                                                                                      | Fine as a _best-effort_ per-instance optimization with TTL; never a correctness guarantee. Use a shared cache (Redis/Upstash) or read models for cross-instance consistency.                                                                                                                                                      |
| **Trusting the default function timeout to "fail fast"**               | The platform ceiling (large and version-dependent under Fluid Compute — **verify**) is a _ceiling_, not a budget; a hung dependency stalls the whole window holding a DB connection.                       | Set explicit `maxDuration` per route **below** your dependency timeouts, so failures land at a known bound.                                                                                                                                                                                                                       |
| **One health endpoint = readiness**                                    | Vercel gives no native liveness/readiness gating, and a health check that pings non-critical upstreams turns any one blip into a self-inflicted outage.                                                    | Split **liveness** (no deps) from **readiness** (critical deps only) as synthetic-monitor/diagnostic endpoints; classify each dependency's criticality. Native LB readiness gating applies only if you also run an external LB / self-hosted worker fleet.                                                                        |

Read `references/serverless-constraints.md` for the full reasoning and edge cases.

## Before you build anything: diagnose the latency floor

Teams routinely build elaborate caching/read-model machinery to defeat a slow-query
number that **only exists in local development**. The most common cause of "every
query takes ~hundreds of ms" is **cross-region round-trips** from a dev laptop to a
managed DB in another region — which largely disappears in production when the function
and DB are colocated.

**Always measure from a deployed preview function, not localhost, and confirm the
Vercel function region matches (or is closest to) the database region before optimizing
roundtrip counts.** This single check is frequently the highest-ROI fix in an entire
hardening effort. See `references/database-postgres.md` → "Region colocation".

## How to run a hardening audit on a project

Work through these in order. Each links to a reference file with patterns, code, and
acceptance criteria. Don't blanket-apply — verify the current state first (a lot of
"standard hardening" is already half-present and mislabeled).

1. **Establish ground truth.** Read the deploy config (`vercel.json`, `next.config.*`),
   the DB client, the middleware, and any existing health/Sentry/metrics setup. Confirm:
   runtime per route, whether Fluid Compute is on, pooler vs direct DB connection,
   function/DB region, what the "health" endpoint actually checks. Don't trust labels —
   read the code and verify limits against current docs.

2. **Confirm the latency floor** (above). Region colocation + prod measurement.

3. **Database hardening** → `references/database-postgres.md`:
   connection bounds, pooler-safe statement timeouts, "prove it in preview" checklist,
   slow-query logging, indexes (`pg_trgm` for `ILIKE`, composite for `ORDER BY ... LIMIT`).

4. **Health, readiness & dependency budgets** → `references/health-and-resilience.md`:
   liveness/readiness split, dependency criticality, per-dependency timeouts, retry
   policy, the breaker caveat, graceful degradation contracts.

5. **Observability** → `references/observability.md`:
   the metrics transport decision (push vs pull by runtime), Sentry spans + tags,
   correlation-id propagation, structured logging with safe redaction, cardinality control.

6. **Caching & frontend data** → `references/caching-and-frontend.md`:
   which cache layer per data shape, where React Query helps and where it's a trap.

7. **Operate it** → `references/alerts-runbooks.md`:
   SLOs, alerts (including pooler saturation), dashboards, runbooks per failure mode.

For a condensed "what good looks like" blueprint (a known-good production stack with
concrete library choices and per-layer checklists), see `references/reference-stack.md` —
useful as both a target and a gap checklist when auditing a project.

## Quick hardening checklist

Use this as a fast pass / PR checklist. Each item expands in its reference file.

- [ ] Function region == DB region (or closest available); latency measured from a deployed function, not localhost.
- [ ] DB client defaults `max: 1` (scale up only from measured concurrency) AND sets `idle_timeout`, `max_lifetime`, `connect_timeout`; consider `attachDatabasePool` under Fluid Compute.
- [ ] `statement_timeout` set durably (prefer `ALTER ROLE` on a dedicated app role), below `maxDuration`; verified in a preview env (`SHOW statement_timeout`).
- [ ] Critical reads also wrapped in an app-level `AbortSignal.timeout()` race.
- [ ] Explicit `maxDuration` on routes that touch external dependencies (don't rely on the platform ceiling).
- [ ] Health trilogy: `/api/health/live` (no deps) · `/api/health/ready` (critical deps, 503) · `/api/health` (combined). All `runtime="nodejs"` + `force-dynamic`. Probed by synthetic monitoring.
- [ ] Each dependency classified critical vs non-critical; non-critical degrades the _route_, not the app.
- [ ] Outbound HTTP calls pass an `AbortSignal.timeout()`; timeouts are typed and distinguishable from upstream 5xx.
- [ ] No in-memory circuit breaker as fleet protection (timeouts + degradation, or a shared-store breaker).
- [ ] Metrics go to a **push** sink (Sentry/OTLP/Vercel Drains), not an in-process scrape endpoint; pull-Prometheus only on long-lived workers.
- [ ] Sentry tracing on, with custom spans + bounded-cardinality tags (`route` pattern, `service`, `dependency`, `degraded`).
- [ ] Correlation id ingested from inbound header (else generated), tagged on logs + Sentry, echoed in response.
- [ ] Structured logging uses an **allowlist** (or explicitly redacts known secret headers/body/URL fields); don't claim arbitrary-depth redaction you haven't implemented.
- [ ] `/api/metrics` (if it exists) disabled-by-default in prod, internal/authenticated, `no-store`, not publicly documented/indexed.
- [ ] Dashboards exist for: app RED metrics, DB latency + **pooler saturation**, each upstream, worker readiness.
- [ ] Runbooks exist for the top failure modes, each pointing at the dashboard panel + trace query that confirms cause.
- [ ] Long-running work lives in a workflow engine / cron, never a synchronous request.

## Principles that keep this from becoming cargo-cult

- **Verify before adding.** Read what's already there; much "missing" hardening is present but mislabeled (e.g. a health check that's really a readiness check). Correct labels before adding machinery. Verify platform limits against current docs, not memory.
- **Right-size to the confirmed problem.** Don't build read models for a latency floor you haven't measured in prod. Resilience effort should follow evidence, not vibes.
- **Fail fast at a known bound** beats failing slow at an unknown one. The whole game on serverless is converting unbounded hangs into bounded, typed, observable failures.
- **Degrade the smallest unit.** A non-critical widget failing should not blank a page; a non-critical dependency down should not fail global readiness.
- **State belongs in shared stores or long-lived processes,** never in a function's memory if correctness depends on it.
- **Separate provider-specific from generic.** Supavisor (Supabase), PgBouncer, and RDS Proxy differ; verify pooler-specific behavior (prepared statements, parameter forwarding) on _your_ provider before relying on it.
