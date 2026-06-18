# Observability — metrics, traces, logs that survive serverless

The core decision is **transport by runtime**: ephemeral web functions push/export; the
long-lived worker can be pulled (scraped). Get this right and everything else follows.

## Metrics transport decision (normative)

| Surface                                    | Transport             | Mechanism                                                                                   | Why                                                       |
| ------------------------------------------ | --------------------- | ------------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| **Web routes / DB / upstream** (ephemeral) | **Push / export**     | Sentry spans+measurements; OTLP → collector; Vercel Drains; Vercel Analytics/Speed Insights | No stable process to scrape; counters reset on cold start |
| **Long-lived worker / daemon**             | **Pull (Prometheus)** | Prometheus endpoint scraped by an agent (Grafana Alloy) → Grafana Cloud                     | Stable process; cumulative counters are valid             |
| **Product analytics**                      | **Push (SDK)**        | PostHog/analytics SDK, ideally via a first-party proxy domain                               | App-level events, not infra                               |
| **Web `/api/metrics`** (optional)          | **Debug only**        | Point-in-time single-instance read, **labeled non-aggregated**, key-gated                   | In-process counters lie on serverless                     |

The trap to avoid: a prom-client `/api/metrics` on the web app. It returns a valid-looking
exposition that reflects one ephemeral instance since its last cold start — misleading.
Reserve pull-Prometheus for the worker.

**If a web `/api/metrics` exists at all, lock it down:** disabled-by-default in production
(behind an env flag) unless something actually consumes it; require **internal/authenticated**
access (an allowlisted internal network or authenticated session), not merely a static key
in a query param; send `Cache-Control: no-store`; mark it `X-Robots-Tag: noindex` and never
link it publicly. It exposes operational shape and is an SSRF/recon target — treat it like an
admin endpoint. The same applies to `/api/health/dependencies`.

## Vercel Drains — push telemetry with near-zero app code

The cleanest serverless transport. Configure once in the Vercel dashboard; no SDK plumbing:

- **Log Drain** → forwards `lambda` / `edge` / `build` logs to your observability backend
  (e.g. Sentry's Vercel log integration). Your structured `pino` JSON to stdout becomes
  searchable centrally.
- **Trace (OTLP) Drain** → forwards serverless function OpenTelemetry traces to an OTLP
  endpoint (e.g. Sentry). Combined with `@vercel/otel` and DB instrumentation, you get
  end-to-end spans without per-route wiring.

This is why "web pushes" is practical, not aspirational — the platform does the shipping.

## Sentry: tracing + route-aware sampling

Tracing is usually trivial to turn on but left at a flat `tracesSampleRate`. Upgrade to a
**`tracesSampler`** that spends your trace budget where it's actionable:

```ts
// sentry.server.config.ts
Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
  enabled: !!process.env.NEXT_PUBLIC_SENTRY_DSN,
  release: process.env.SENTRY_RELEASE ?? process.env.VERCEL_GIT_COMMIT_SHA,
  environment: process.env.VERCEL_ENV ?? process.env.NODE_ENV,
  tracesSampler: (ctx) => {
    if (ctx.name?.includes('/api/health')) return 0 // never trace health probes
    if (ctx.name?.includes('/api/')) return 0.5 // API routes: high value
    if (ctx.parentSampled === false) return 0.05 // background/worker-ish
    return 0.2 // pages / RSC
  },
})
```

Sample **lower on the client/edge** than the server (page navigations are high-volume,
low-signal). Keep `beforeSendTransaction` returning the event unless you have a reason for
tail sampling.

Split init by runtime in `instrumentation.ts` (Node gets full init + bootstrap; edge gets a
minimal, lower-sampled init):

```ts
export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') await import('../sentry.server.config')
  if (process.env.NEXT_RUNTIME === 'edge') await import('../sentry.edge.config')
}
export const onRequestError = Sentry.captureRequestError // auto-capture route errors
```

## Spans and tags

Add custom spans around the work that actually causes latency, and tag them with
**bounded-cardinality** dimensions so they're queryable without exploding storage:

- Spans around: DB query groups, each external API call, workflow/Temporal client calls,
  expensive service methods.
- Tags: `route` (the **pattern** `"/users/[id]"`, never the concrete URL), `service`,
  `dependency`, `degraded` (bool), and a `requestId` for log correlation.
- DB spans for free via OpenTelemetry Drizzle instrumentation (`@kubiks/otel-drizzle`) or
  `@vercel/otel`; capture query **shape** in prod, full text only in dev.

Cardinality is the silent killer of metrics bills and query performance: never tag with
user ids, full URLs, or unbounded values.

## Structured logging with redaction

Use `pino` (JSON to stdout in prod; `pino-pretty` in dev). Vercel captures stdout; the Log
Drain ships it. Two non-negotiables:

**1. Allowlist first, redact second.** The safest design is to **construct log objects from
an allowlist** of known-safe fields, so a secret can't leak just because someone logged a
whole `req`/`user`/`error` object. Redaction is a backstop, not the primary control.

A wildcard `redact` config is a useful backstop but **does not** cover "any nesting depth":
pino `redact` paths are explicit, don't match arbitrary depth, and miss arrays
(`headers.foo[0]`), case variants, `set-cookie` on responses, bearer tokens embedded in
URLs/query strings, and bodies. Don't claim arbitrary-depth coverage you haven't built.

```ts
// Backstop redaction — explicitly enumerate the dangerous KNOWN paths, including response
// cookies and request sub-objects. This is NOT a substitute for allowlisting log fields.
export const redact = {
  paths: [
    'password',
    'token',
    'secret',
    'apiKey',
    'api_key',
    'connectionString',
    'database_url',
    'req.headers.authorization',
    'req.headers.cookie',
    'res.headers["set-cookie"]',
    'req.body.password',
    'req.body.token',
    'headers.authorization',
    'headers.cookie',
    '*.password',
    '*.token',
    '*.secret',
    '*.authorization',
    '*.cookie',
  ],
  censor: '[REDACTED]',
  remove: false,
}

const logger = pino({ level: process.env.LOG_LEVEL ?? 'info', base: { service: 'web' }, redact })
```

Also strip secrets that hide in **URLs/query strings** (e.g. `?token=...`, basic-auth in a
DB URL) before logging a URL — redaction keyed on object paths won't catch those.

**2. Context binding** — child loggers carrying request-scoped fields so every line is
correlatable:

```ts
export function createContextLogger(ctx: { requestId?: string; userId?: string; orgId?: string }) {
  const b: Record<string, string> = {}
  if (ctx.requestId) b.requestId = ctx.requestId
  if (ctx.userId) b.userId = ctx.userId
  if (ctx.orgId) b.orgId = ctx.orgId
  return logger.child(b)
}
```

Never log: secrets/keys, bound query values, prompts, image payloads, or raw request
bodies. Truncate SQL and large fields.

## Correlation id propagation (the connective tissue)

One id threads logs ↔ traces ↔ response, so an incident is one query away from the full
story:

1. **Generate or ingest** in middleware: read `x-request-id` from the inbound request; if
   absent, generate (`req-${nanoid()}`). Stamp it on the request and the **response**
   header.
2. **Bind** it into the context logger in each route handler.
3. **Tag** it on Sentry: `Sentry.setTag("requestId", requestId)`.

Middleware (`proxy.ts`) runs **before** the handler, so it's the right place to stamp the
request/response header — but it can't observe the handler's internal work, so the binding
to the logger/Sentry happens in the route handler. (Next.js `proxy.ts` now defaults to the
Node runtime, so it _can_ do Node work if configured; the division of labor still holds —
stamp in middleware, bind/observe in the handler.)

## Multi-destination, no single point of failure

Mature stacks route signals to fit-for-purpose backends rather than one tool:

- **Errors + traces** → Sentry (SDK + Vercel Drains).
- **Infra/worker metrics** → Prometheus → Grafana Alloy → Grafana Cloud.
- **Worker logs** → stdout + a log backend (e.g. Axiom via `@axiomhq/pino`) for retention.
- **Product analytics / session replay** → PostHog (via a first-party proxy domain to dodge
  ad blockers; mask inputs in replay).
- **Web vitals** → Sentry and/or Vercel Speed Insights.

You don't need all of these on day one — but know which destination each signal type belongs
in, and don't try to force serverless RED metrics into a pull-Prometheus shape.
