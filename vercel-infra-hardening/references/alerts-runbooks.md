# SLOs, Alerts, Dashboards & Runbooks

Observability is only useful if it drives action. This is the operate-it layer: define what
"good" means, alert when it isn't, and give the on-call a fixed diagnosis path.

## SLOs — define "good" before alerting on "bad"

Pick a small set of indicators with explicit targets. Suggested starting set:

| SLI                         | Example target                                     | Notes                                      |
| --------------------------- | -------------------------------------------------- | ------------------------------------------ |
| App route p95 latency       | < 1.5s (lists), < 2s (dashboards)                  | Measure in prod, per route pattern         |
| API route p95 latency       | < 1s (excl. async workflow starts)                 | Long work belongs in a worker              |
| DB query p95 latency        | region-appropriate (low double-digit ms colocated) | From slow-query logs / OTel spans          |
| Upstream API p95 latency    | per dependency                                     | Distinguish timeout vs upstream 5xx        |
| Readiness success rate      | ~100%                                              | `/api/health/ready` from synthetic monitor |
| Worker poller readiness     | always ready when expected                         | From worker `/ready` + Prometheus          |
| Workflow start success rate | ~100%                                              | Workflow-engine metrics                    |

## Alerts — what to page on

Split **app failure** from **dependency degradation** — they need different responses.

**Infrastructure / worker (from Prometheus → Grafana, or platform monitors):**

- Worker down: `up{job="worker"} == 0` for ~2m → critical.
- App down: synthetic check fails from ≥2 probes → critical.
- **DB pooler saturation** (the most likely real incident): client-connection usage near
  the pooler limit, or rising `pg_stat_activity` waiting count → high.
- Worker memory/CPU/disk sustained high → warning.
- Workflow task-queue backlog: schedule-to-start latency above budget for ~5m → warning.
- Upstream gRPC/HTTP failure count > 0 sustained → high.

**Application (from Sentry / error backend):**

- New unhandled error (first-seen, level ≥ error).
- Error spike (> N events/hour).
- Regression (resolved issue reappears).
- Fatal error (level ≥ fatal) — fast page.
- Many users affected (> N unique users/hour).

Tune thresholds to real traffic; start conservative and adjust to cut noise. Route to a real
destination (email/Slack/pager) someone actually watches.

## Synthetic monitoring

Probe `/api/health/ready` (and the homepage) from **multiple regions** every ~2 minutes.
This is your continuous, external measurement of real prod latency and uptime — far more
trustworthy than anecdotes or local-dev numbers, and it's what catches region/colocation
regressions.

## Dashboards — one per failure domain

- **App overview** — RED metrics (rate, errors, duration) per route pattern.
- **Database** — query p95, error rate, and **pooler saturation** (the panel that explains
  most "site got slow" incidents).
- **Each upstream dependency** — call volume, timeout vs 5xx split, p95.
- **Worker** — status/up, active pollers, task-queue schedule-to-start latency, workflow
  completed/failed rate, available slots.
- **Infra (if self-hosting a worker)** — CPU, memory, disk, load.

## Runbooks — fixed diagnosis path per failure mode

Write one per top failure mode; each should name the **dashboard panel** and the **trace/log
query** that confirms the cause, then the remediation. Minimum set:

- **Slow admin page** → check route p95 panel + Sentry trace for the route → identify slow
  query group / dependency → apply index / parallelize / degrade.
- **DB latency spike** → DB dashboard + slow-query logs → check pooler saturation first.
- **Pooler / connection exhaustion** → pooler saturation panel + `pg_stat_activity` →
  reduce per-instance `max`, confirm `idle_timeout`/`max_lifetime`, check for a connection
  leak or a traffic spike; short-term, scale the pooler.
- **Upstream degraded** → dependency dashboard (timeout vs 5xx) → confirm degraded routes
  are isolating the failure (readiness still green) → enable/verify fallback.
- **Worker not ready** → worker dashboard + `/ready` → check deploy/poller/connection to the
  workflow service.
- **Error spike** → Sentry issue → group by release/route/requestId → correlate to a deploy.

## Keep runbooks and config in the repo

Put SLOs, alert definitions, dashboard JSON, and runbooks under `docs/ops/` (or similar) in
the repo so they're versioned, reviewable, and discoverable — not trapped in a vendor UI.
Cross-link them from the project README and CLAUDE.md so on-call finds them under pressure.
