# Health, Readiness & Request Resilience

How to turn unbounded hangs into bounded, typed, observable failures — the whole game on
serverless.

## The health-endpoint trilogy

Don't ship one `/api/health` that hits the DB and call it done — that conflates two
different questions and lets a non-critical dependency pull the whole app out of rotation.

**Vercel caveat:** unlike Kubernetes, Vercel provides **no native liveness/readiness
gating** — there's no platform that restarts a "dead" function or pulls an "unready"
instance out of rotation based on these endpoints. On a pure Vercel app these are
**synthetic-monitoring and diagnostic** endpoints (probed by Grafana SM / your uptime
checker), and the value is the _criticality split_, not platform orchestration. The
Kubernetes-style "restart trigger / readiness gate" semantics only apply if you **also** run
an external load balancer or a self-hosted worker fleet (the worker is where real liveness/
readiness gating lives — see `reference-stack.md`).

| Endpoint            | Question it answers                    | Checks                          | Used by (Vercel)                              |
| ------------------- | -------------------------------------- | ------------------------------- | --------------------------------------------- |
| `/api/health/live`  | Is the process able to respond at all? | **Nothing** (return 200)        | Synthetic uptime check                        |
| `/api/health/ready` | Are critical deps within budget?       | **Critical** deps only (DB)     | Synthetic monitor; LB readiness gate _if any_ |
| `/api/health`       | Combined human-facing status           | Critical deps + reports latency | Dashboards, status pages                      |

```ts
// /api/health/live — liveness: no dependencies, always cheap
export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'
export const GET = () => Response.json({ status: 'ok', timestamp: new Date().toISOString() })

// /api/health/ready — readiness: critical dependency only, bounded
export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'
export async function GET() {
  const start = performance.now()
  try {
    const ok = await Promise.race([
      testDatabaseConnection(),
      new Promise<never>((_, rej) => setTimeout(() => rej(new Error('db timeout')), 5000)),
    ])
    if (!ok) {
      logger.warn('health.ready.db_unavailable')
      return Response.json({ status: 'degraded', db: 'unreachable' }, { status: 503 })
    }
    return Response.json({
      status: 'ready',
      db: 'connected',
      latencyMs: Math.round(performance.now() - start),
    })
  } catch (e) {
    logger.error('health.ready.error', { error: String(e) })
    return Response.json({ status: 'degraded' }, { status: 503 })
  }
}
```

Always `runtime = "nodejs"` (these touch the DB) and `dynamic = "force-dynamic"` (never
serve a cached health result). If your auth middleware protects everything by default,
**add the health endpoints to its public allowlist** or they'll 401/redirect the probes.

## Dependency criticality classification

The single most important resilience decision: **which dependencies, when down, should
fail readiness vs. degrade only the routes that use them.**

- **Critical (fail `/ready`, pull instance from rotation):** the primary database. Without
  it the app can serve almost nothing.
- **Non-critical (degrade the _route_, keep `/ready` green):** external APIs (auth provider
  status, CRM, LLM providers, third-party data). A blip in one of these must **not** blank
  the whole app. Surface their status in a detailed `/api/health/dependencies` endpoint
  (authenticated) for visibility, but keep them out of the readiness gate.

Getting this wrong is a classic self-inflicted outage: a health check that pings five
upstreams turns any one upstream's hiccup into a full app outage.

## Outbound HTTP timeouts

Every outbound call needs an explicit timeout — the platform default will let it hang to
the function ceiling, holding a connection the whole time.

```ts
const TIMEOUT_MS = 10_000

// Option A — AbortController + setTimeout (works everywhere, easy to clear)
const controller = new AbortController()
const t = setTimeout(() => controller.abort(), TIMEOUT_MS)
try {
  const res = await fetch(url, { signal: controller.signal })
  // ...
} finally {
  clearTimeout(t)
}

// Option B — AbortSignal.timeout (concise; Node 18+/modern runtimes)
const res = await fetch(url, { signal: AbortSignal.timeout(TIMEOUT_MS) })

// Combine an internal timeout with an external cancellation signal:
const res2 = await fetch(url, {
  signal: AbortSignal.any([AbortSignal.timeout(TIMEOUT_MS), externalAbortSignal]),
})
```

If you call an SDK rather than `fetch` directly, check whether it accepts a per-call
`signal`/`AbortSignal` (most fetch-based generated clients do via a request-options arg).
If it does, pass `AbortSignal.timeout(...)`. **Make timeout errors typed and distinguishable
from upstream `5xx`** so dashboards can tell "we gave up" from "they failed."

## Retry policy

- **Retry only idempotent, safe operations** (GETs, idempotent writes with keys). Never
  blind-retry a non-idempotent POST.
- **Don't retry 4xx** (except `429`) — a validation/auth failure won't succeed on retry.
- **Do retry `429` and transient `5xx`** with capped exponential backoff.
- **On web, prefer failing fast over retrying** under a function ceiling — a retry loop
  can blow the `maxDuration`. Push retry-heavy work to a durable worker/workflow engine
  where retries are first-class.

Client-side (React Query) is a great place for user-facing retry — see
`caching-and-frontend.md`:

```ts
retry: (failureCount, error) => {
  if (error instanceof ApiError && error.status >= 400 && error.status < 500 && error.status !== 429)
    return false;        // 4xx (except 429) not retryable
  return failureCount < 3;
},
retryDelay: (i) => Math.min(1000 * 2 ** i, 30_000), // exp backoff, capped 30s
```

## Circuit breakers — the serverless caveat

An in-memory breaker is **per-instance**: under Fluid Compute it may persist across
invocations on one warm instance, but it's never shared across the fleet — so it can't
provide aggregate protection for a fragile upstream (see `serverless-constraints.md`). On
web paths use **timeouts + degradation** instead. If you need real aggregate breaking, back
it with a shared store (Redis/Upstash) or move the fragile call into a long-lived worker
(where module-memory breakers are valid). Don't add `opossum` in a module variable and
assume it protects the upstream fleet-wide.

## Rate limiting

For public/high-abuse endpoints, use a **shared-store** limiter (the only kind that works
across instances), e.g. Upstash Ratelimit on Redis:

```ts
import { Ratelimit } from '@upstash/ratelimit'
import { Redis } from '@upstash/redis'

const limiter = new Ratelimit({ redis: Redis.fromEnv(), limiter: Ratelimit.slidingWindow(10, '60 s'), analytics: true })
const { success } = await limiter.limit(clientIp)
if (!success) return apiError('rate limited', 429)
```

Decide the **fail-open vs fail-closed** posture deliberately: fail **closed** in prod (a
missing Redis config should throw at startup, not silently disable protection), and you may
fail **open** in local dev for convenience.

## Graceful degradation contracts

Give every degradable surface a small status vocabulary so the UI can render honestly:

`fresh` · `stale` · `partial` · `unavailable`

Patterns:

- **Fail toward visibility, not concealment.** A status/health proxy that can't reach the
  upstream should report `degraded: true`, not pretend everything's fine:

  ```ts
  export const revalidate = 120 // cache the upstream status at the edge for 2 min
  export async function GET() {
    try {
      const res = await fetch(STATUS_URL, { next: { revalidate: 120 } })
      if (!res.ok) return Response.json({ degraded: true, reason: 'status_error' })
      const data = await res.json()
      return Response.json({ degraded: data.indicator !== 'none', indicator: data.indicator })
    } catch {
      return Response.json({ degraded: true, reason: 'unreachable' }) // assume down
    }
  }
  ```

- **Non-critical widgets fail independently** — a failed summary card shows a compact error
  - retry, it does not throw the whole page.
- **Stale-with-label** — cached reference data renders with a "last updated" timestamp
  rather than blocking on a fresh fetch.

## Non-critical side effects: `after()` / `waitUntil`

Don't block the response (or risk dropping work) on non-critical post-request effects
(analytics, notifications, webhooks). Use Next.js `after()` (or `event.waitUntil`) so the
work runs **after** the response is sent and its failure can't fail the request:

```ts
import { after } from 'next/server'

export async function POST(req: Request) {
  await db.insert(/* critical write */)
  after(() => {
    captureAnalytics(userId, 'thing_happened') // fire-and-forget, post-response
  })
  return apiSuccess({ ok: true })
}
```

Remember it's still bounded by the function lifetime — anything heavy or long-running
belongs in a queue/workflow engine, not `after()`.

## Request budgets, end to end

Wire the budgets so failures land in a sane order, all inside the function ceiling:

1. Route declares `export const maxDuration = N` (the function ceiling for that route).
2. DB `statement_timeout` (or per-read race) < N.
3. Outbound `AbortSignal.timeout()` < N.
4. On breach: typed timeout error → controlled degraded response → tagged in Sentry +
   slow-route log.

The goal is that a slow dependency produces a **fast, typed, observed** failure — never a
silent stall that holds a connection until the platform kills it.
