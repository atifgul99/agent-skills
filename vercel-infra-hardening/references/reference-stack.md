# Reference Stack — a known-good, production-proven blueprint

A condensed, generic blueprint distilled from a mature production stack
(Next.js 16 on Vercel + Supabase Postgres via `postgres.js`/Drizzle + a Temporal worker on
a VPS). Use it as a "what good looks like" target and a gap checklist. Adapt names; keep the
shapes.

## Topology

```
Vercel (Next.js, ephemeral functions)          Long-lived worker (VPS / container)
├─ @sentry/nextjs ───────────► Sentry          ├─ workflow SDK (Temporal/Inngest/…)
├─ OTel DB spans ─► Vercel Trace Drain ─► Sentry├─ Prometheus :PORT ─► Alloy ─► Grafana Cloud
├─ pino → stdout ─► Vercel Log Drain ─► Sentry  ├─ @sentry/node ───────────► Sentry
├─ @vercel/analytics + speed-insights           ├─ pino → stdout + Axiom (retention)
├─ analytics SDK ─► PostHog (first-party proxy) └─ Node Exporter :PORT ─► Alloy ─► Grafana
└─ Upstash Redis (rate limit / shared state)
            │
            ▼
   Supabase Postgres (pgBouncer transaction pooler :6543)
```

Key division of labor: **web pushes** telemetry (Drains/Sentry/PostHog); **worker is
scraped** (Prometheus). Background/durable work lives in the worker, never in a request.

## Web app — checklist of concrete pieces

- **Health trilogy:** `/api/health/live` (no deps), `/api/health/ready` (DB-critical, 503),
  `/api/health` (combined). All `runtime="nodejs"`, `dynamic="force-dynamic"`, auth-exempt.
  On a pure Vercel app these are synthetic-monitor/diagnostic endpoints (no native gating).
- **DB client** (`postgres.js`): `max: 1` default (raise only from measured concurrency —
  Fluid Compute multiplies connections), `idle_timeout: 20`, `max_lifetime: 1800`,
  `connect_timeout: 10`, `ssl: "require"`, `prepare: false` (needed for Supavisor txn mode /
  unverified poolers — verify if you want prepared statements); consider Vercel
  `attachDatabasePool`; driver-level slow-query logger (`SLOW_QUERY_MS ~200`); OTel Drizzle
  spans (`captureQueryText` dev-only). One mature stack runs `max: 10` tuned to its measured
  concurrency + pooler headroom — that's a _measured_ exception, not the default.
- **Sentry:** split server/client/edge init via `instrumentation.ts`; route-aware
  `tracesSampler` (0 health, ~0.5 api, ~0.2 pages server; lower on client/edge);
  `onRequestError = Sentry.captureRequestError`; `release` from `VERCEL_GIT_COMMIT_SHA`.
- **Logging:** `pino` JSON→stdout (prod) / `pino-pretty` (dev); depth-aware `redact` of
  secrets; `createContextLogger({ requestId, userId, orgId })` child loggers.
- **Request id:** generated/ingested in middleware (`x-request-id`), bound to logger,
  `Sentry.setTag`, echoed on the response.
- **Resilience:** explicit `maxDuration` on heavy routes; outbound `fetch` with
  `AbortController`/`AbortSignal.timeout` (~10s); typed errors with `classification` +
  `suggestion` + `isRetryable`.
- **Caching:** React Query (TanStack) with centralized STALE/POLL/GC constants and
  status-aware retry; Next `revalidate` ISR for external status reads; API routes default
  `Cache-Control: no-store`.
- **Degradation:** `error.tsx` per major segment; status endpoints that **fail toward
  visibility** (assume degraded when unreachable); `after()` for non-critical side effects.
- **Rate limiting:** Upstash Ratelimit (shared store) on public endpoints; fail-closed in
  prod, fail-open in dev.
- **Security headers/CSP:** static headers in `next.config`; per-request CSP in middleware;
  HSTS preload. (Adjacent to hardening; worth doing in the same pass.)

## Worker — checklist

- Prometheus metrics on a bound port, scraped by an agent (Grafana Alloy) → Grafana Cloud.
- `@sentry/node` for errors + spans.
- `pino` → stdout **and** a retention backend (e.g. Axiom via `@axiomhq/pino`); a
  `flushLogger()` with a timeout on shutdown so logs aren't lost on exit.
- In-memory breakers/counters are **valid here** (long-lived process). Lean on the workflow
  engine's native retry/backoff/timeout for durability.
- Graceful shutdown: stop accepting work / close the health server **before** draining, so
  the LB de-registers the instance first.

## Ops — checklist

- `docs/ops/` with: monitoring overview, worker ops, database ops, security hardening,
  incident response — versioned in the repo.
- Grafana dashboards (worker, infra) + Sentry alerts (errors) + synthetic monitors
  (multi-region `/api/health/ready`).
- Alert destinations a human watches; thresholds tuned to real traffic.

## Notable libraries seen in this stack (all reusable)

| Concern                   | Library                                               |
| ------------------------- | ----------------------------------------------------- |
| Errors/traces             | `@sentry/nextjs`, `@sentry/node`                      |
| DB OTel spans             | `@kubiks/otel-drizzle` (or `@vercel/otel`)            |
| Logging                   | `pino`, `pino-pretty`, `@axiomhq/pino`                |
| Rate limit / shared state | `@upstash/ratelimit`, `@upstash/redis`                |
| Product analytics         | `posthog-js` / `posthog-node` (via first-party proxy) |
| Web vitals                | `@vercel/analytics`, `@vercel/speed-insights`         |
| Client cache              | `@tanstack/react-query`                               |
| DB driver / ORM           | `postgres` (postgres.js) + `drizzle-orm`              |

## How to use this file

When auditing a new project, diff it against these checklists. Missing items aren't
automatically required — weigh each against the project's scale and the **confirmed** prod
latency floor — but each absence should be a conscious decision, not an oversight. Start
with the health trilogy, DB connection bounds, and request-id + structured logging: they're
high-value, low-cost, and unlock everything downstream.
