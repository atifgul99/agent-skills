---
name: temporal-expert
description: >
  Temporal.io workflow orchestration expert for TypeScript and Python. Durable execution,
  fault-tolerant distributed systems, saga patterns, long-running workflows, activity retries,
  workflow versioning, schedules, signals, queries, updates, and MCP integration.
  Use when: implementing Temporal workflows or activities, designing durable execution patterns,
  building worker services, connecting Temporal to Next.js/Node.js apps, deploying Temporal
  (self-hosted Docker or Temporal Cloud), building MCP tools backed by Temporal workflows,
  saga/compensation patterns, scheduled job orchestration, or reviewing Temporal code.
  Triggers: "temporal", "workflow orchestration", "durable execution", "saga pattern",
  "activity retry", "workflow versioning", "temporal worker", "temporal client",
  "temporal cloud", "temporal schedule", "MCP temporal", "durable MCP", "long-running workflow",
  "workflow signal", "workflow query", "task queue", "temporal deploy".
---

# Temporal Expert

Temporal provides durable execution for distributed applications. Workflows run to completion
regardless of failures — the platform handles retries, timeouts, and state persistence
automatically. Code is deterministic replay-safe; side effects live in activities.

## When to Read Reference Files

- **TypeScript SDK** (workflows, activities, workers, client): See [references/typescript-sdk.md](references/typescript-sdk.md)
- **Python SDK** (workflows, activities, workers, client): See [references/python-sdk.md](references/python-sdk.md)
- **Deployment** (Docker Compose, Temporal Cloud, VPS, CI/CD): See [references/deployment.md](references/deployment.md)
- **MCP Integration** (Temporal MCP Server, durable MCP tools, agentic patterns): See [references/mcp-integration.md](references/mcp-integration.md)
- **Testing** (local test server, mocking, Vitest/pytest patterns): See [references/testing.md](references/testing.md)

## Core Concepts (Quick Reference)

### Architecture

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────┐
│  Client App  │────▶│  Temporal Server  │◀────│   Worker    │
│  (Next.js)   │     │  (Cloud / Self)   │     │  (Node/Py)  │
└─────────────┘     └──────────────────┘     └─────────────┘
     │                       │                       │
  start/signal/          persistence            execute
  query workflows        + scheduling           workflows
                                                + activities
```

- **Workflow**: Deterministic orchestration function. Survives crashes via event sourcing replay.
- **Activity**: Non-deterministic side-effect (API call, DB write, file I/O). Retried on failure.
- **Worker**: Process that polls a task queue and executes workflows + activities.
- **Client**: Starts workflows, sends signals, queries state, manages schedules.
- **Task Queue**: Named queue binding workflows/activities to workers. Multiple workers can share one.
- **Signal**: Async message sent to a running workflow (fire-and-forget).
- **Query**: Sync read of workflow state (no side effects, no mutation).
- **Update**: Sync message + response (validate → execute → return result).
- **Schedule**: Cron-like trigger that starts workflows on a recurring basis.

### Determinism Rules (CRITICAL)

Workflow code MUST be deterministic. On replay, the same code must produce the same commands.

**NEVER do in workflow code:**
- Network/HTTP calls (use activities)
- File I/O or database access (use activities)
- `Math.random()` or `crypto.randomUUID()` (use `workflow.random()` in Python or `uuid4()` from `@temporalio/workflow`)
- `Date.now()` or `new Date()` (use Temporal's time APIs)
- Global mutable state
- Non-deterministic iteration (e.g., iterating `Map` keys in some runtimes)
- `setTimeout` / `setInterval` (use `workflow.sleep()` or timers)

**ALWAYS do in workflow code:**
- Call activities via `proxyActivities` (TS) or `workflow.execute_activity` (Python)
- Use `workflow.sleep()` for delays
- Use `workflow.condition()` (TS) or `workflow.wait_condition()` (Python) for blocking waits
- Use signals/queries/updates for external interaction
- Keep workflow functions pure orchestration logic

### Timeout Hierarchy

| Timeout | Scope | Default | Use |
|---------|-------|---------|-----|
| `workflowExecutionTimeout` | Entire workflow including retries | None | Hard cap on total workflow life |
| `workflowRunTimeout` | Single workflow run | None | Cap on single execution attempt |
| `scheduleToCloseTimeout` | Activity: schedule → complete | None | End-to-end activity deadline |
| `startToCloseTimeout` | Activity: start → complete | None | Execution time limit (most common) |
| `scheduleToStartTimeout` | Activity: schedule → worker picks up | None | Detect worker backlog |
| `heartbeatTimeout` | Activity: between heartbeats | None | Detect stuck long activities |

Rule: Always set `startToCloseTimeout` on every activity. Add `heartbeatTimeout` for activities > 60s.

### Retry Policy Defaults

```
initialInterval:    1s
backoffCoefficient: 2.0
maximumInterval:    100 × initialInterval
maximumAttempts:    unlimited
nonRetryableErrors: [] (all errors retried by default)
```

Override per-activity. Mark errors as non-retryable when retrying won't help (validation errors, auth failures, business logic rejections).

### Saga Pattern (Compensation)

For distributed transactions across multiple services:

```
1. Step A succeeds → record compensation_A
2. Step B succeeds → record compensation_B
3. Step C fails → run compensation_B then compensation_A (reverse order)
```

Compensations are activities. Run them in reverse order. Each compensation should be idempotent.
See TypeScript and Python reference files for full examples.

### Workflow ID Best Practices

Use business-meaningful, deterministic IDs for idempotency:

- `order-{orderId}` — one workflow per order
- `user-{userId}-onboarding` — one onboarding per user
- `campaign-{campaignId}-publish` — one publish per campaign
- `schedule-post-{postId}` — one scheduled publish per post

Temporal rejects duplicate workflow IDs (same namespace + ID + running). This is a feature — it prevents double-processing.

### Versioning Workflows

When changing workflow logic while executions are in-flight:

**TypeScript**: Use `patched()` / `deprecatePatch()`
**Python**: Use `workflow.patched()` / `workflow.deprecate_patch()`

Three-phase lifecycle:
1. Deploy with `patched('my-change')` guard — new code runs for new + replaying workflows
2. Once all old executions complete, replace `patched()` with `deprecatePatch()`
3. Once no replays need the old path, remove the patch entirely

### Anti-Patterns Checklist

- [ ] No I/O in workflows (network, disk, DB) — use activities
- [ ] No non-deterministic code in workflows — no random, no wallclock time
- [ ] No unbounded lists in workflow state — paginate or use child workflows
- [ ] No single mega-activity — split into focused, retryable units
- [ ] No missing timeouts on activities
- [ ] No ignoring heartbeats on long-running activities
- [ ] No hardcoded Temporal addresses — use env vars
- [ ] No workflow logic in activities — activities are leaf operations
- [ ] No sharing workflow instances across task queues

## Decision Matrix

| Scenario | Pattern |
|----------|---------|
| Multi-step process with rollback | Saga with compensation activities |
| Waiting for external approval | Signal + `condition()`/`wait_condition()` with timeout |
| Recurring job (e.g., daily sync) | Schedule → Workflow |
| Fan-out parallel work | Multiple `executeActivity` / child workflows + `Promise.all` |
| Long-running process (hours/days) | Heartbeated activities + continue-as-new for large histories |
| Exactly-once processing | Deterministic workflow ID + idempotent activities |
| Human-in-the-loop via AI | MCP tools → Temporal signals/queries (see mcp-integration.md) |
| Publish social post at future time | Schedule or `workflow.sleep()` until publish time |
