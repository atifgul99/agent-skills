# Database Hardening — managed Postgres behind a pooler, from serverless

Patterns here are validated against a production Next.js-on-Vercel + Supabase (postgres.js

- Drizzle) stack. They generalize to Neon, RDS Proxy, and any pgBouncer-style pooler.

## Region colocation — do this first

The most common "everything is slow" cause is **cross-region round-trips**, and it's
usually a _local-dev measurement artifact_:

- A query from a dev laptop to a managed DB in another region pays wide-area RTT
  (often hundreds of ms). The same query from a Vercel function colocated with the DB
  pays single-digit-to-low-double-digit ms.
- Measuring from `localhost` and then engineering caches/read-models to defeat that
  number is wasted effort that doesn't help prod.

**Actions:**

1. Confirm the Vercel function region (project setting / `vercel.json` `regions`) equals
   the DB region.
2. Measure the real floor from a **deployed preview function**, e.g. a temporary route
   that times `SELECT 1` and an empty-table read, and log the duration.
3. Add **synthetic monitoring** that hits `/api/health` from a couple of regions so you
   keep measuring prod latency continuously, not anecdotally.

Only after the prod floor is known should you decide how much caching/read-model work is
justified.

## Connection pooling — the nuance that bites

The failure mode: functions scale **horizontally**, so total DB connections ≈
(number of warm instances) × (per-instance pool `max`). A spike spawns many instances and
exhausts the database's connection ceiling — the site stalls until things drain (or you
restart). This is _the_ canonical serverless-Postgres incident.

**Default to the smallest pool that works, then scale from measurement.** Supabase and
Vercel serverless guidance is blunt: for typical request/response traffic, **`max: 1` is
often optimal**. With Fluid Compute, a single instance serves multiple concurrent
invocations, so total client connections ≈ instances × per-instance concurrency × `max` —
a generous `max` multiplies fast and exhausts the pooler. Start at `1` and raise only when
a measured concurrency profile and real pooler headroom justify it.

- **Direct to Postgres (no pooler):** `max` 1–3, hard cap. Postgres' `max_connections` is
  small (often ~100 total including everything).
- **Through a transaction pooler (Supabase Supavisor / PgBouncer / RDS Proxy):** the pooler
  multiplexes, but per-instance concurrency still multiplies your client connections —
  `max: 1`–small is still the safe default; the pooler's `max_client_conn` is the real
  ceiling to respect.

What matters as much as `max` on serverless is **fast release** — idle and old connections
must close so warm instances don't hoard pooler slots. On Vercel, also consider
**`attachDatabasePool`** (Vercel's Fluid-Compute connection-management primitive for
supported pool clients) so the platform can manage pooled connections across invocations.

### Known-good postgres.js config

```ts
import postgres from 'postgres'

const client = postgres(process.env.DATABASE_URL!, {
  max: 1, // default; raise ONLY from measured concurrency + pooler headroom (Fluid multiplies this)
  idle_timeout: 20, // close idle conns after 20s — frees pooler slots on serverless
  max_lifetime: 1800, // recycle conns after 30m — defends against stale/leaked connections
  connect_timeout: 10, // bound the initial handshake so a dead DB fails fast, not hangs
  ssl: 'require', // managed Postgres requires TLS
  // prepare: false is needed for Supavisor transaction mode and unverified poolers.
  // Modern PgBouncer CAN support protocol-level prepared statements if configured —
  // verify on YOUR pooler before assuming prepare:false is mandatory.
  prepare: false,
  onnotice: () => {}, // silence NOTICE spam
})
```

Don't cargo-cult the numbers — `max: 1` is the conservative default, not a law; tune from
measurement. But always set `idle_timeout`, `max_lifetime`, and `connect_timeout` on
serverless. (`max_lifetime` is safe on serverless: it just caps how long a reused
connection lives; a recycle on an idle instance is cheap.)

## Statement timeouts — set them pooler-safely (or don't, deliberately)

Two valid philosophies; pick one consciously rather than leaving queries unbounded:

**A. Durable `statement_timeout` (defense in depth).** With transaction pooling, a loose
session `SET statement_timeout` may not carry to the next pooled transaction. Set it where
it sticks, in this order of preference:

- **Preferred: `ALTER ROLE <dedicated app role> SET statement_timeout = '8000ms';`** —
  applies to every session of that role. Use a **dedicated** app role, not a shared one:
  applying this to a role also used by migrations/admin/CLI tools will kill legitimate
  long-running maintenance queries.
- **`SET LOCAL statement_timeout = '3s'`** for a tight per-read budget — but **only inside
  an explicit transaction** (`SET LOCAL` outside a transaction is a no-op). With a wrapping
  transaction it's pooler-safe because it's scoped to that one transaction.
- **Connection string `...?options=-c%20statement_timeout%3D8000`** — `libpq` supports
  `options`, but transaction poolers only guarantee a narrow set of startup parameters, and
  not every pooler (e.g. Supavisor) reliably forwards this. **Verify it actually applied in
  a preview env (`SHOW statement_timeout`) before relying on it.**

Pick a ceiling above normal page budgets but **below** the route's `maxDuration`, so a
runaway query dies as a controlled DB error inside the function window.

**B. Rely on `maxDuration` + `connect_timeout` + slow-query logging.** Some mature stacks
deliberately _don't_ set `statement_timeout` (to avoid killing legitimate admin/migration
queries) and instead bound hangs with the route `maxDuration`, bound connection failures
with `connect_timeout`, and rely on slow-query logging to catch regressions. This is
acceptable **if** every data route has an explicit `maxDuration` below the platform ceiling.

The anti-pattern is neither: no `statement_timeout` **and** no `maxDuration`, leaving a
hung query to consume the full default function window and a pooler slot.

## Prove pooler behavior in a preview env (don't assume)

Pooler behavior is provider-specific (Supavisor ≠ PgBouncer ≠ RDS Proxy) and changes
across versions. Before relying on any of the above, validate against the **real** provider
from a deployed preview function — not localhost, not docs:

- **Statement timeout actually applied:** run `SHOW statement_timeout;` through the app's
  pooled connection and confirm the value you expect.
- **Prepared statements:** if you want `prepare: true` for perf, run a smoke test (a few
  parameterized queries under concurrency) and confirm no "prepared statement does not
  exist / already exists" errors. If they appear, keep `prepare: false`.
- **Pool saturation:** drive concurrent load and watch the pooler's client-connection usage
  and `pg_stat_activity` waiting count. Confirm your `max` × expected concurrency stays
  under the pooler ceiling.
- **Region/latency floor:** time `SELECT 1` and an empty-table read from the preview
  function and record the real prod floor.

Capture the results in the repo (a short `docs/ops/db-pooler-verification.md`) so the next
person doesn't re-derive them.

## Slow-query logging independent of trace sampling

Trace sampling (e.g. 20–50%) means most slow queries never appear in Sentry. Add a
**driver-level** timer that logs every slow query regardless of sampling. Pattern: wrap the
driver's query path, time it, and log above a threshold (truncate the SQL, never log bound
values):

```ts
const SLOW_QUERY_MS = 200

// postgres.js: wrap the .unsafe() path Drizzle uses for all queries
const originalUnsafe = client.unsafe.bind(client)
client.unsafe = ((query: string, params?: unknown[], ...rest: unknown[]): any => {
  const start = performance.now()
  const result = (originalUnsafe as any)(query, params, ...rest)
  const originalThen = result.then.bind(result)
  result.then = (onF?: any, onR?: any) =>
    originalThen(
      (v: unknown) => {
        const ms = Math.round(performance.now() - start)
        const sql = query.slice(0, 300) // truncate; never log full values
        if (ms > SLOW_QUERY_MS) logger.warn('db.slow_query', { durationMs: ms, query: sql })
        else logger.debug('db.query', { durationMs: ms, query: sql })
        return onF ? onF(v) : v
      },
      (e: unknown) => {
        const ms = Math.round(performance.now() - start)
        logger.error('db.query_error', { durationMs: ms, query: query.slice(0, 300), error: String(e) })
        if (onR) return onR(e)
        throw e
      },
    )
  return result
}) as typeof client.unsafe
```

Pair this with **OpenTelemetry DB spans** for sampled deep traces — e.g.
`@kubiks/otel-drizzle` (`instrumentDrizzleClient(db, { dbSystem: "postgresql", captureQueryText: env.NODE_ENV !== "production" })`).
Capture full query text in dev only; in prod capture shape, not values.

## Health-check query

Keep the readiness DB probe trivial and bounded:

```ts
export async function testDatabaseConnection(): Promise<boolean> {
  try {
    await client`SELECT 1`
    return true
  } catch (e) {
    logger.error('db.health_failed', { error: String(e) })
    return false
  }
}
```

Race it against a short timeout in the readiness handler (see `health-and-resilience.md`)
so a hung DB returns `503` quickly instead of stalling the probe.

## Indexes — the specific gaps that hurt list pages

Admin/list endpoints over a remote DB are dominated by the `ORDER BY ... LIMIT` plan and
filter selectivity. Common, verifiable gaps:

- **`ORDER BY created_at DESC LIMIT n` with an id tiebreaker** → add a **composite**
  `(created_at, id)` (or `(created_at DESC, id DESC)`) index matching the exact order. A
  plain `created_at` index won't fully cover the tiebreaker.
- **`ILIKE '%term%'` search** → **btree indexes do not help leading-wildcard matches.**
  Use a `pg_trgm` GIN index: `CREATE EXTENSION IF NOT EXISTS pg_trgm;` then
  `CREATE INDEX ... USING gin (col gin_trgm_ops);`. On small tables, accept the scan and
  document it — don't add a btree index expecting it to accelerate `%term%`.
- **Join/group-by foreign keys** (junction tables especially) → index the FK columns the
  grouped `COUNT(...) ... WHERE fk IN (...)` queries filter on.
- **Filter columns** used in `WHERE status = ... / tier = ...` → index if selective.

Always confirm with `EXPLAIN (ANALYZE, BUFFERS)` on realistic data **before** claiming a
win — an index the planner ignores is just write overhead.

## Pagination — drop the serial pre-count where you can

A `count()` issued **before** the list (to compute a page window) serializes two
round-trips, doubling the latency floor on that route. Two fixes:

1. **`hasMore` pagination** — fetch `limit + 1` rows; if you got `limit + 1`, there's a
   next page. No count at all. Best for operational lists where exact total pages aren't
   user-essential.
2. **Parallelize** count and list with `Promise.all` when you genuinely need the exact
   total (compute offset from the requested page, clamp after the count returns).

For dashboard cards, prefer **approximate counts** from `pg_class.reltuples` /
`pg_stat_user_tables.n_live_tup` (a single metadata query) over exact `COUNT(*)` per table.
Label approximate values in the UI.
