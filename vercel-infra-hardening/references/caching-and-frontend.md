# Caching Strategy & Frontend Data (React Query)

The recurring mistake: reaching for React Query (or any client cache) to "fix" a slow page.
It can't — the first server render already happened slowly before any client cache exists.
Match the cache layer to the data shape.

## Cache layer by data shape

| Data shape                                              | Layer                                | Mechanism                                                                 | Notes                                                            |
| ------------------------------------------------------- | ------------------------------------ | ------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| Initial server-rendered page (first paint)              | **Server-side query optimization**   | indexes, parallel reads, region colocation                                | A client cache cannot fix initial server latency — fix the query |
| External reference data (slow-changing)                 | **Edge/ISR fetch cache**             | `fetch(url, { next: { revalidate } })` or route `export const revalidate` | TTL-cache third-party calls (status pages, config)               |
| Expensive dashboard summaries                           | **Server read-model / shared cache** | precomputed table, or Redis/Upstash                                       | Only if a measured prod floor justifies it                       |
| Cross-instance state (counters, locks, breakers)        | **Shared store**                     | Redis/Upstash, or a DB row                                                | Never module memory on serverless                                |
| Per-instance best-effort hot data                       | **In-memory w/ TTL**                 | module map + TTL + in-flight dedup                                        | Optimization only; never a correctness guarantee                 |
| Interactive client state (filters, pagination, polling) | **React Query**                      | TanStack Query                                                            | The right and only good fit for client cache                     |
| Mutations / optimistic UI                               | **React Query**                      | mutations + invalidation                                                  | Invalidate only the affected keys                                |

## Where React Query genuinely helps

- **Interactive filter/sort/pagination after first load** — reuse cached pages, instant UX.
- **Status/job polling** — pipeline runs, generation progress, workflow status, with
  background refresh and automatic stop on terminal states.
- **Optimistic mutations** with targeted cache invalidation.

Where it does **not** help: initial server-render latency, DB timeouts, upstream
resilience, readiness, route-level metrics. React Query is a UX layer, not a backend
resilience layer.

## Provider config (sane defaults)

```ts
const isNonRetryable = (e: unknown) => e instanceof ApiError && e.status >= 400 && e.status < 500 && e.status !== 429

new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60_000, // tune per data class (see below)
      gcTime: 10 * 60_000,
      refetchOnWindowFocus: false, // opt in per-page, not blanket
      refetchOnReconnect: true,
      retry: (n, e) => (isNonRetryable(e) ? false : n < 3),
      retryDelay: (i) => Math.min(1000 * 2 ** i, 30_000),
      throwOnError: false,
    },
    mutations: {
      retry: (n, e) => (e instanceof ApiError && e.status === 429 ? n < 3 : false),
      retryDelay: (i) => Math.min(1000 * 2 ** i, 30_000),
    },
  },
})
```

Centralize stale/poll/gc constants so they're consistent and tunable:

```ts
export const STALE = { standard: 300_000, slow: 600_000, static: 3_600_000 } // 5m / 10m / 1h
export const POLL = { fast: 5_000, medium: 8_000, slow: 30_000 } // job status / etc.
export const GC = { default: 600_000 }
```

- **Static/reference data** (platform metadata, profile): `staleTime` ~1h.
- **List views**: ~5m.
- **Aggregated stats/dropdowns**: ~10m.
- **Polling**: stop when the job reaches a terminal state (`refetchInterval: (q) => isDone ? false : POLL.fast`).

## Server-side fetch caching for external calls

Cache slow-changing third-party reads at the edge instead of hitting them every request:

```ts
export const revalidate = 120 // route-level ISR

export async function GET() {
  const res = await fetch(STATUS_URL, { next: { revalidate: 120 } }) // same TTL on the fetch
  // ... return a small, typed degraded-aware payload
}
```

## API responses: default to no-store, opt into caching deliberately

Dynamic data routes should return `Cache-Control: no-store` so stale admin state never
leaks; reserve caching for the specific endpoints where it's correct (reference/status):

```ts
const NO_CACHE = { 'Cache-Control': 'no-store, max-age=0' } as const
export const apiSuccess = <T>(data: T, status = 200) => Response.json({ data }, { status, headers: NO_CACHE })
```

## Client data fetching boundary

- Don't import server-only service functions into client components — expose **typed,
  paginated, bounded** route handlers instead, and call those from React Query.
- Decide per route whether it's user-scoped (keep under auth middleware) or machine-readable
  (exempt + key-gate).
- Keep payloads bounded (pagination, field selection) so a client cache doesn't pull
  unbounded data.

## Error classification drives client behavior

Have the API return a **classification**, not just a status, so the client knows whether to
retry, prompt re-auth, or show a validation message:

```ts
// server: map a typed error to status + guidance
switch (error.classification) {
  case 'refresh-token':
    return apiError(msg, 401, { suggestion: 'Reconnect the account' })
  case 'rate-limit':
    return apiError(msg, 429, { isRetryable: true })
  case 'retry':
    return apiError(msg, error.isRetryable ? 502 : 500, { isRetryable: error.isRetryable })
  case 'bad-body':
    return apiError(msg, 400, { isRetryable: false })
}
```

React Query's `retry` predicate then keys off status (`429`/`5xx` retryable, other `4xx`
not), and the UI can render the `suggestion` instead of a generic "something went wrong."

## Error boundaries

Give every major route segment an `error.tsx` boundary with a compact, actionable fallback
(message + reset/retry), and capture to Sentry with `route`/`requestId` tags. A scoped
boundary degrades one section; a missing one blanks the whole tree.
