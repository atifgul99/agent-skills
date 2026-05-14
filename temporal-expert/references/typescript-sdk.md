# Temporal TypeScript SDK Reference

## Table of Contents

1. [Installation & Project Setup](#installation--project-setup)
2. [Workflow Definition](#workflow-definition)
3. [Activity Definition](#activity-definition)
4. [Worker Setup](#worker-setup)
5. [Client Usage](#client-usage)
6. [Signals, Queries, and Updates](#signals-queries-and-updates)
7. [Child Workflows](#child-workflows)
8. [Timers and Conditions](#timers-and-conditions)
9. [Saga Pattern](#saga-pattern)
10. [Continue-As-New](#continue-as-new)
11. [Schedules](#schedules)
12. [Versioning (Patching)](#versioning-patching)
13. [Error Handling](#error-handling)
14. [Workflow Cancellation](#workflow-cancellation)
15. [Next.js Integration](#nextjs-integration)

---

## Installation & Project Setup

```bash
# New project from template
npx @temporalio/create@latest ./my-temporal-app

# Add to existing project
pnpm add @temporalio/client @temporalio/worker @temporalio/workflow @temporalio/activity
```

Recommended project structure:

```
src/temporal/
├── activities/          # Activity implementations (I/O, side effects)
│   ├── post.activities.ts
│   └── campaign.activities.ts
├── workflows/           # Workflow definitions (deterministic orchestration)
│   ├── post.workflows.ts
│   └── campaign.workflows.ts
├── worker.ts            # Worker entry point
├── client.ts            # Shared Temporal client factory
├── task-queues.ts       # Task queue name constants
└── types.ts             # Shared workflow/activity input/output types
```

TypeScript SDK requires Node.js >= 18. Workflows run in a sandboxed V8 isolate — they cannot import
Node.js built-ins or make network calls directly.

---

## Workflow Definition

Workflows are deterministic functions. They orchestrate activities and child workflows.

```typescript
// src/temporal/workflows/post.workflows.ts
import { proxyActivities, defineSignal, defineQuery, setHandler, condition, sleep } from '@temporalio/workflow'
import type { PostActivities } from '../activities/post.activities'

const { publishToplatform, uploadMedia, notifyUser } = proxyActivities<PostActivities>({
  startToCloseTimeout: '30s',
  retry: {
    initialInterval: '1s',
    backoffCoefficient: 2,
    maximumAttempts: 3,
    nonRetryableErrorTypes: ['ValidationError', 'AuthenticationError'],
  },
})

export const cancelSignal = defineSignal('cancel')
export const statusQuery = defineQuery<string>('status')

export async function publishPostWorkflow(input: PublishPostInput): Promise<PublishPostResult> {
  let status = 'preparing'
  let cancelled = false

  setHandler(statusQuery, () => status)
  setHandler(cancelSignal, () => { cancelled = true })

  // Wait until scheduled time
  const now = Date.now()
  if (input.scheduledAt > now) {
    const waitMs = input.scheduledAt - now
    // condition returns false on timeout (not cancelled), true if cancelled
    const wasCancelled = await condition(() => cancelled, waitMs)
    if (wasCancelled) {
      return { status: 'cancelled', postId: input.postId }
    }
  }

  status = 'uploading_media'
  const mediaUrls = input.mediaIds.length > 0
    ? await uploadMedia({ postId: input.postId, mediaIds: input.mediaIds })
    : []

  status = 'publishing'
  const results = await Promise.all(
    input.platformChannels.map((channel) =>
      publishToplatform({
        postId: input.postId,
        channelId: channel.id,
        platform: channel.platform,
        content: input.content,
        mediaUrls,
      })
    )
  )

  status = 'notifying'
  await notifyUser({
    userId: input.userId,
    postId: input.postId,
    results,
  })

  status = 'completed'
  return { status: 'published', postId: input.postId, platformResults: results }
}
```

Key rules:
- `proxyActivities` creates typed proxies. Always set `startToCloseTimeout`.
- Workflow functions are `async` and exported by name. The function name = workflow type.
- Use `defineSignal`, `defineQuery`, `defineUpdate` + `setHandler` for external interaction.
- `condition(fn, timeout?)` blocks until `fn` returns `true` or timeout expires.
- `sleep(duration)` for Temporal-safe timers (survives replay).

---

## Activity Definition

Activities perform I/O — API calls, database writes, file operations. They run in the normal
Node.js environment (not sandboxed).

```typescript
// src/temporal/activities/post.activities.ts
import { log, heartbeat, activityInfo, cancelled } from '@temporalio/activity'

export interface PostActivities {
  publishToplatform(input: PublishInput): Promise<PlatformResult>
  uploadMedia(input: MediaInput): Promise<string[]>
  notifyUser(input: NotifyInput): Promise<void>
}

export async function publishToplatform(input: PublishInput): Promise<PlatformResult> {
  log.info('Publishing post', { postId: input.postId, platform: input.platform })

  const response = await fetch(`https://api.${input.platform}.com/posts`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${getToken(input.platform)}` },
    body: JSON.stringify({ content: input.content, media: input.mediaUrls }),
  })

  if (!response.ok) {
    const error = await response.text()
    if (response.status === 401) {
      throw new NonRetryableError(`Auth failed for ${input.platform}: ${error}`)
    }
    throw new Error(`Platform API error ${response.status}: ${error}`)
  }

  return response.json()
}

export async function uploadMedia(input: MediaInput): Promise<string[]> {
  const urls: string[] = []
  for (let i = 0; i < input.mediaIds.length; i++) {
    heartbeat(`Uploading ${i + 1}/${input.mediaIds.length}`)
    const url = await processAndUpload(input.mediaIds[i])
    urls.push(url)
  }
  return urls
}
```

Key rules:
- Activities are normal async functions. They CAN use Node.js built-ins, network, DB, etc.
- `heartbeat(details)` — call periodically for long activities. Temporal detects stuck activities
  when heartbeats stop. Details are available on retry for resuming.
- Throw `ApplicationFailure.nonRetryable(message)` or a custom error type listed in
  `nonRetryableErrorTypes` to stop retries.
- Activity functions must be registered with the worker (see Worker Setup).

### Non-Retryable Errors

```typescript
import { ApplicationFailure } from '@temporalio/common'

// Option 1: Throw ApplicationFailure directly
throw ApplicationFailure.nonRetryable('Payment declined', 'PaymentDeclined')

// Option 2: List error types in retry policy (workflow side)
const { charge } = proxyActivities<PaymentActivities>({
  startToCloseTimeout: '30s',
  retry: { nonRetryableErrorTypes: ['PaymentDeclined', 'ValidationError'] },
})
```

---

## Worker Setup

The worker connects to Temporal Server, polls task queues, and executes workflows + activities.

```typescript
// src/temporal/worker.ts
import { Worker, NativeConnection } from '@temporalio/worker'
import * as activities from './activities/post.activities'
import { TASK_QUEUES } from './task-queues'

async function run() {
  const connection = await NativeConnection.connect({
    address: process.env.TEMPORAL_ADDRESS ?? 'localhost:7233',
    // For Temporal Cloud with API key:
    // tls: true,
    // metadata: { 'temporal-namespace': process.env.TEMPORAL_NAMESPACE },
    // apiKey: process.env.TEMPORAL_API_KEY,

    // For Temporal Cloud with mTLS:
    // tls: {
    //   clientCertPair: {
    //     crt: readFileSync(process.env.TEMPORAL_TLS_CERT!),
    //     key: readFileSync(process.env.TEMPORAL_TLS_KEY!),
    //   },
    // },
  })

  const worker = await Worker.create({
    connection,
    namespace: process.env.TEMPORAL_NAMESPACE ?? 'default',
    taskQueue: TASK_QUEUES.POST_PROCESSING,
    workflowsPath: require.resolve('./workflows/post.workflows'),
    activities,
    maxConcurrentActivityTaskExecutions: 20,
    maxConcurrentWorkflowTaskExecutions: 40,
  })

  console.log('Worker started, polling task queue:', TASK_QUEUES.POST_PROCESSING)
  await worker.run()
}

run().catch((err) => {
  console.error('Worker failed:', err)
  process.exit(1)
})
```

Key points:
- `workflowsPath` uses `require.resolve()` — Temporal bundles workflows into a V8 isolate at startup.
- `activities` are passed as an object — activity functions are NOT sandboxed.
- One worker can handle multiple task queues by creating multiple `Worker` instances.
- `NativeConnection` is for workers; `Connection` (from `@temporalio/client`) is for clients.
- Worker should run as a separate process (not inside your Next.js server).

### Task Queue Constants

```typescript
// src/temporal/task-queues.ts
export const TASK_QUEUES = {
  POST_PROCESSING: 'post-processing',
  CAMPAIGN_MANAGEMENT: 'campaign-management',
  ANALYTICS_SYNC: 'analytics-sync',
  MEDIA_PROCESSING: 'media-processing',
} as const

export type TaskQueue = (typeof TASK_QUEUES)[keyof typeof TASK_QUEUES]
```

---

## Client Usage

The client starts workflows, sends signals, and queries state. Use from API routes, scripts, etc.

```typescript
// src/temporal/client.ts
import { Client, Connection } from '@temporalio/client'

let clientInstance: Client | null = null

export async function getTemporalClient(): Promise<Client> {
  if (clientInstance) return clientInstance

  const connection = await Connection.connect({
    address: process.env.TEMPORAL_ADDRESS ?? 'localhost:7233',
    // tls + apiKey or tls.clientCertPair for Temporal Cloud
  })

  clientInstance = new Client({
    connection,
    namespace: process.env.TEMPORAL_NAMESPACE ?? 'default',
  })

  return clientInstance
}
```

### Starting Workflows

```typescript
import { getTemporalClient } from '@/temporal/client'
import { publishPostWorkflow } from '@/temporal/workflows/post.workflows'
import { TASK_QUEUES } from '@/temporal/task-queues'

const client = await getTemporalClient()

// Start and wait for result
const result = await client.workflow.execute(publishPostWorkflow, {
  taskQueue: TASK_QUEUES.POST_PROCESSING,
  workflowId: `publish-post-${postId}`,
  args: [{ postId, content, platformChannels, scheduledAt, mediaIds, userId }],
  workflowExecutionTimeout: '24h',
})

// Start and get handle (don't wait)
const handle = await client.workflow.start(publishPostWorkflow, {
  taskQueue: TASK_QUEUES.POST_PROCESSING,
  workflowId: `publish-post-${postId}`,
  args: [input],
})
console.log('Started workflow:', handle.workflowId)

// Get handle to existing workflow
const existing = client.workflow.getHandle(`publish-post-${postId}`)
const status = await existing.query(statusQuery)
await existing.signal(cancelSignal)
const finalResult = await existing.result()
```

---

## Signals, Queries, and Updates

### Signals (fire-and-forget input to workflow)

```typescript
// Define in workflow file
export const approvalSignal = defineSignal<[{ approved: boolean; approvedBy: string }]>('approval')

// Handle in workflow function
setHandler(approvalSignal, ({ approved, approvedBy }) => {
  approvalResult = { approved, approvedBy, at: Date.now() }
})
await condition(() => approvalResult !== undefined, '7d')

// Send from client
const handle = client.workflow.getHandle(workflowId)
await handle.signal(approvalSignal, { approved: true, approvedBy: 'user-123' })
```

### Queries (sync read of workflow state)

```typescript
// Define + handle
export const progressQuery = defineQuery<{ completed: number; total: number }>('progress')
setHandler(progressQuery, () => ({ completed, total }))

// Query from client
const progress = await handle.query(progressQuery)
```

### Updates (sync request → validate → mutate → respond)

```typescript
import { defineUpdate, setHandler } from '@temporalio/workflow'

export const addItemUpdate = defineUpdate<OrderItem, [AddItemInput]>('addItem')

setHandler(addItemUpdate, (input) => {
  items.push({ id: input.itemId, qty: input.quantity })
  return items[items.length - 1]
}, {
  validator: (input) => {
    if (input.quantity <= 0) throw new Error('Quantity must be positive')
  },
})

// From client
const newItem = await handle.executeUpdate(addItemUpdate, { args: [{ itemId: 'sku-1', quantity: 2 }] })
```

---

## Child Workflows

Break large workflows into smaller, independently retriable units.

```typescript
import { executeChild, startChild } from '@temporalio/workflow'

// Execute and wait
const result = await executeChild(processLineItemWorkflow, {
  workflowId: `line-item-${lineItemId}`,
  args: [lineItemInput],
})

// Start without waiting (fire-and-forget)
const childHandle = await startChild(processLineItemWorkflow, {
  workflowId: `line-item-${lineItemId}`,
  args: [lineItemInput],
})
```

Use child workflows when:
- Each sub-task needs its own retry/timeout policies
- Workflow history would grow too large (> 10k events)
- Sub-tasks are logically independent and can run in parallel
- You need `continue-as-new` semantics for subsets of work

---

## Timers and Conditions

```typescript
import { sleep, condition } from '@temporalio/workflow'

// Sleep for a duration
await sleep('5m')
await sleep(1000 * 60 * 5) // 5 minutes in ms

// Wait until condition or timeout
const fulfilled = await condition(() => isApproved, '24h')
if (!fulfilled) {
  // Timed out — not approved within 24 hours
}

// Race: first activity to complete wins
const result = await Promise.race([
  callPrimaryApi(input),
  sleep('10s').then(() => callFallbackApi(input)),
])
```

---

## Saga Pattern

```typescript
export async function orderSagaWorkflow(order: OrderInput): Promise<OrderResult> {
  const compensations: Array<() => Promise<void>> = []

  try {
    const reservation = await reserveInventory(order.items)
    compensations.push(() => releaseInventory(reservation.id))

    const payment = await chargePayment({ orderId: order.id, amount: order.total })
    compensations.push(() => refundPayment(payment.id))

    const shipment = await createShipment({ orderId: order.id, address: order.address })
    return { orderId: order.id, shipmentId: shipment.id, status: 'completed' }

  } catch (err) {
    // Run compensations in reverse order
    for (const compensate of compensations.reverse()) {
      try {
        await compensate()
      } catch (compErr) {
        log.error('Compensation failed', { error: compErr })
        // Log but don't rethrow — best-effort compensation
      }
    }
    throw err
  }
}
```

---

## Continue-As-New

For workflows that run indefinitely or accumulate large event histories:

```typescript
import { continueAsNew } from '@temporalio/workflow'

export async function pollingWorkflow(state: PollState): Promise<void> {
  for (let i = 0; i < 100; i++) {
    const result = await pollForUpdates(state.lastCursor)
    state.lastCursor = result.cursor
    state.processedCount += result.items.length
    await sleep('30s')
  }
  // Reset history by continuing as new with current state
  await continueAsNew<typeof pollingWorkflow>(state)
}
```

Use when event history approaches ~10k events or workflow runs for extended periods.

---

## Schedules

Create recurring workflows (replaces cron jobs).

```typescript
const client = await getTemporalClient()

const schedule = await client.schedule.create({
  scheduleId: 'daily-analytics-sync',
  spec: {
    cronExpressions: ['0 2 * * *'], // 2 AM daily
  },
  action: {
    type: 'startWorkflow',
    workflowType: syncAnalyticsWorkflow,
    taskQueue: TASK_QUEUES.ANALYTICS_SYNC,
    args: [{ source: 'all-platforms' }],
  },
  policies: {
    overlap: 'SKIP', // Skip if previous run still active
    catchupWindow: '1h',
  },
})

// Manage existing schedule
const handle = client.schedule.getHandle('daily-analytics-sync')
await handle.pause('Maintenance window')
await handle.unpause()
await handle.trigger() // Run immediately
await handle.delete()
```

---

## Versioning (Patching)

Safe workflow code changes while executions are in-flight:

```typescript
import { patched, deprecatePatch } from '@temporalio/workflow'

export async function myWorkflow(input: Input): Promise<Output> {
  if (patched('add-validation-step')) {
    // New code path — runs for new executions and replaying ones that already took this branch
    await validateInput(input)
  }
  // else: old path — runs for replaying executions that never hit the patch

  const result = await processData(input)
  return result
}
```

Lifecycle:
1. Deploy with `patched('id')` — both paths exist
2. All old executions complete → replace with `deprecatePatch('id')`
3. No more replays need old path → remove patch entirely

---

## Error Handling

```typescript
import { ApplicationFailure, isCancellation } from '@temporalio/workflow'

export async function workflowWithErrorHandling(input: Input): Promise<Output> {
  try {
    return await doWork(input)
  } catch (err) {
    if (isCancellation(err)) {
      // Workflow was cancelled — run cleanup
      await cleanup(input)
      throw err // Re-throw to mark workflow as cancelled
    }
    // Application error — propagate to caller
    throw ApplicationFailure.create({
      message: `Workflow failed: ${err}`,
      type: 'WorkflowFailed',
      nonRetryable: true,
    })
  }
}
```

---

## Workflow Cancellation

```typescript
import { CancellationScope, isCancellation } from '@temporalio/workflow'

export async function cancellableWorkflow(input: Input): Promise<Output> {
  try {
    const result = await doMainWork(input)
    return result
  } catch (err) {
    if (isCancellation(err)) {
      // Run cleanup in a non-cancellable scope so it completes even during cancellation
      await CancellationScope.nonCancellable(async () => {
        await cleanupActivity(input)
      })
    }
    throw err
  }
}

// Cancel from client
const handle = client.workflow.getHandle(workflowId)
await handle.cancel()
```

---

## Next.js Integration

### API Route → Temporal Client

```typescript
// src/app/api/posts/[id]/publish/route.ts
import { getTemporalClient } from '@/temporal/client'
import { publishPostWorkflow } from '@/temporal/workflows/post.workflows'
import { TASK_QUEUES } from '@/temporal/task-queues'
import { requireWorkspaceAuth } from '@/lib/auth'
import { apiSuccess, handleRouteError } from '@/lib/api'

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { workspaceId } = await requireWorkspaceAuth()
    const { id: postId } = await params

    const client = await getTemporalClient()
    const handle = await client.workflow.start(publishPostWorkflow, {
      taskQueue: TASK_QUEUES.POST_PROCESSING,
      workflowId: `publish-post-${workspaceId}-${postId}`,
      args: [{ postId, workspaceId }],
    })

    return apiSuccess({ workflowId: handle.workflowId, status: 'started' })
  } catch (error) {
    return handleRouteError(error)
  }
}
```

### Checking Workflow Status

```typescript
// src/app/api/posts/[id]/publish-status/route.ts
export async function GET(request: Request, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { workspaceId } = await requireWorkspaceAuth()
    const { id: postId } = await params

    const client = await getTemporalClient()
    const handle = client.workflow.getHandle(`publish-post-${workspaceId}-${postId}`)
    const description = await handle.describe()

    return apiSuccess({
      status: description.status.name,
      startTime: description.startTime,
    })
  } catch (error) {
    return handleRouteError(error)
  }
}
```

Worker runs as a **separate process** from Next.js — not inside your web server.
Deploy the worker as its own Docker container or process.
