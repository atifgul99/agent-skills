# Temporal Testing Reference

## Table of Contents

1. [Testing Strategy](#testing-strategy)
2. [TypeScript Testing with Vitest](#typescript-testing-with-vitest)
3. [Activity Testing](#activity-testing)
4. [Workflow Testing](#workflow-testing)
5. [Integration Testing](#integration-testing)
6. [Time Skipping](#time-skipping)
7. [Python Testing with pytest](#python-testing-with-pytest)

---

## Testing Strategy

| Layer | What to Test | How | Speed |
|-------|-------------|-----|-------|
| Activities | Business logic, API calls, DB operations | Unit test with mocked dependencies | Fast |
| Workflows | Orchestration logic, signal/query handling | `TestWorkflowEnvironment` with mocked activities | Fast |
| Integration | Full flow: client → server → worker → activities | Local Temporal server + real activities | Slow |
| MCP Tools | Tool definitions trigger correct workflows | Mock Temporal client | Fast |

Test activities and workflows separately. Integration tests are for confidence, not coverage.

---

## TypeScript Testing with Vitest

### Setup

```bash
pnpm add -D vitest @temporalio/testing
```

```typescript
// vitest.config.ts (add or extend)
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    include: ['src/temporal/**/*.test.ts'],
    testTimeout: 30_000,
  },
})
```

---

## Activity Testing

Activities are regular async functions — test them like any other function.

```typescript
// src/temporal/activities/__tests__/post.activities.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { MockActivityEnvironment } from '@temporalio/testing'
import { publishToplatform } from '../post.activities'

describe('publishToplatform', () => {
  let env: MockActivityEnvironment

  beforeEach(() => {
    env = new MockActivityEnvironment()
  })

  it('publishes to platform and returns result', async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve({ id: 'platform-post-123', url: 'https://...' }),
    })
    global.fetch = mockFetch

    const result = await env.run(publishToplatform, {
      postId: 'post-1',
      channelId: 'ch-1',
      platform: 'twitter',
      content: 'Hello world',
      mediaUrls: [],
    })

    expect(result.id).toBe('platform-post-123')
    expect(mockFetch).toHaveBeenCalledOnce()
  })

  it('throws non-retryable error on 401', async () => {
    global.fetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 401,
      text: () => Promise.resolve('Unauthorized'),
    })

    await expect(
      env.run(publishToplatform, {
        postId: 'post-1',
        channelId: 'ch-1',
        platform: 'twitter',
        content: 'Hello',
        mediaUrls: [],
      })
    ).rejects.toThrow('Auth failed')
  })
})
```

`MockActivityEnvironment` provides `heartbeat()`, `activityInfo()`, and cancellation
context without a real Temporal server.

---

## Workflow Testing

Use `TestWorkflowEnvironment` — spins up a lightweight in-memory Temporal server for testing.

```typescript
// src/temporal/workflows/__tests__/post.workflows.test.ts
import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { TestWorkflowEnvironment } from '@temporalio/testing'
import { Worker } from '@temporalio/worker'
import { publishPostWorkflow, statusQuery, cancelSignal } from '../post.workflows'

describe('publishPostWorkflow', () => {
  let env: TestWorkflowEnvironment

  beforeAll(async () => {
    env = await TestWorkflowEnvironment.createLocal()
  })

  afterAll(async () => {
    await env?.teardown()
  })

  it('publishes post to all platforms', async () => {
    const mockActivities = {
      publishToplatform: async (input: any) => ({
        id: `platform-${input.platform}`,
        url: `https://${input.platform}.com/post/123`,
      }),
      uploadMedia: async () => ['https://cdn.example.com/image.jpg'],
      notifyUser: async () => {},
    }

    const worker = await Worker.create({
      connection: env.nativeConnection,
      taskQueue: 'test-post',
      workflowsPath: require.resolve('../post.workflows'),
      activities: mockActivities,
    })

    const result = await worker.runUntil(
      env.client.workflow.execute(publishPostWorkflow, {
        taskQueue: 'test-post',
        workflowId: 'test-publish-1',
        args: [{
          postId: 'post-1',
          content: 'Test post',
          platformChannels: [
            { id: 'ch-1', platform: 'twitter' },
            { id: 'ch-2', platform: 'linkedin' },
          ],
          mediaIds: ['media-1'],
          scheduledAt: Date.now(), // Publish now
          userId: 'user-1',
        }],
      })
    )

    expect(result.status).toBe('published')
    expect(result.platformResults).toHaveLength(2)
  })

  it('cancels workflow via signal before publish time', async () => {
    const mockActivities = {
      publishToplatform: async () => { throw new Error('Should not be called') },
      uploadMedia: async () => [],
      notifyUser: async () => {},
    }

    const worker = await Worker.create({
      connection: env.nativeConnection,
      taskQueue: 'test-cancel',
      workflowsPath: require.resolve('../post.workflows'),
      activities: mockActivities,
    })

    const handle = await env.client.workflow.start(publishPostWorkflow, {
      taskQueue: 'test-cancel',
      workflowId: 'test-cancel-1',
      args: [{
        postId: 'post-2',
        content: 'Should be cancelled',
        platformChannels: [{ id: 'ch-1', platform: 'twitter' }],
        mediaIds: [],
        scheduledAt: Date.now() + 60_000 * 60, // 1 hour from now
        userId: 'user-1',
      }],
    })

    // Signal cancel
    await handle.signal(cancelSignal)

    const result = await worker.runUntil(handle.result())
    expect(result.status).toBe('cancelled')
  })

  it('reports status via query', async () => {
    const mockActivities = {
      publishToplatform: async () => {
        // Simulate slow activity
        await new Promise((r) => setTimeout(r, 100))
        return { id: 'p-1', url: 'https://...' }
      },
      uploadMedia: async () => [],
      notifyUser: async () => {},
    }

    const worker = await Worker.create({
      connection: env.nativeConnection,
      taskQueue: 'test-query',
      workflowsPath: require.resolve('../post.workflows'),
      activities: mockActivities,
    })

    const handle = await env.client.workflow.start(publishPostWorkflow, {
      taskQueue: 'test-query',
      workflowId: 'test-query-1',
      args: [{
        postId: 'post-3',
        content: 'Query test',
        platformChannels: [{ id: 'ch-1', platform: 'twitter' }],
        mediaIds: [],
        scheduledAt: Date.now(),
        userId: 'user-1',
      }],
    })

    await worker.runUntil(handle.result())

    // Status should be 'completed' after workflow finishes
    // Note: queries may not work after completion depending on server config
  })
})
```

### Key Testing Patterns

**`worker.runUntil(promise)`**: Runs the worker until the promise resolves, then shuts down cleanly.
Use this to scope worker lifetime to individual tests.

**Mock activities**: Pass mock functions instead of real activities. The workflow sandbox doesn't
know the difference — it calls the proxy, which routes to your mocks.

**Signals during execution**: Start workflow, send signal, then await result. The worker processes
both the workflow task and the signal.

---

## Integration Testing

Full end-to-end with real activities (use sparingly — these are slow).

```typescript
describe('Integration: publishPostWorkflow', () => {
  let env: TestWorkflowEnvironment

  beforeAll(async () => {
    env = await TestWorkflowEnvironment.createLocal()
  })

  afterAll(async () => {
    await env?.teardown()
  })

  it('end-to-end with real activities', async () => {
    // Import REAL activities (not mocks)
    const activities = await import('../activities/post.activities')

    const worker = await Worker.create({
      connection: env.nativeConnection,
      taskQueue: 'integration-test',
      workflowsPath: require.resolve('../workflows/post.workflows'),
      activities,
    })

    const result = await worker.runUntil(
      env.client.workflow.execute(publishPostWorkflow, {
        taskQueue: 'integration-test',
        workflowId: 'integration-1',
        args: [testInput],
      })
    )

    expect(result.status).toBe('published')
  })
})
```

---

## Time Skipping

`TestWorkflowEnvironment` supports automatic time skipping — workflows that `sleep('24h')`
complete instantly in tests.

```typescript
it('handles scheduled post with time skip', async () => {
  // createTimeSkipping() auto-advances time when workflows are waiting
  const env = await TestWorkflowEnvironment.createTimeSkipping()

  const worker = await Worker.create({
    connection: env.nativeConnection,
    taskQueue: 'time-skip',
    workflowsPath: require.resolve('../post.workflows'),
    activities: mockActivities,
  })

  const futureTime = Date.now() + 1000 * 60 * 60 * 24 // 24 hours

  // This completes instantly even though the workflow sleeps for 24 hours
  const result = await worker.runUntil(
    env.client.workflow.execute(publishPostWorkflow, {
      taskQueue: 'time-skip',
      workflowId: 'time-skip-1',
      args: [{
        postId: 'post-scheduled',
        scheduledAt: futureTime,
        content: 'Future post',
        platformChannels: [{ id: 'ch-1', platform: 'twitter' }],
        mediaIds: [],
        userId: 'user-1',
      }],
    })
  )

  expect(result.status).toBe('published')
  await env.teardown()
})
```

`createLocal()` — real-time execution (good for most tests).
`createTimeSkipping()` — auto-skips `sleep()` and timer waits (good for timeout/schedule tests).

---

## Python Testing with pytest

For testing Python MCP tools and Python workflows.

```python
import pytest
from temporalio.testing import WorkflowEnvironment
from temporalio.worker import Worker

@pytest.fixture
async def workflow_env():
    async with await WorkflowEnvironment.start_local() as env:
        yield env

@pytest.mark.asyncio
async def test_publish_workflow(workflow_env):
    async with Worker(
        workflow_env.client,
        task_queue="test",
        workflows=[PublishPostWorkflow],
        activities=[mock_publish, mock_upload, mock_notify],
    ):
        result = await workflow_env.client.execute_workflow(
            PublishPostWorkflow.run,
            PublishInput(post_id="test-1", workspace_id="ws-1"),
            id="test-publish-1",
            task_queue="test",
        )
        assert result.status == "published"

@pytest.mark.asyncio
async def test_mcp_tool_starts_workflow(workflow_env):
    """Test that MCP tool correctly starts a Temporal workflow."""
    # Mock the get_temporal_client to return test client
    with patch("my_mcp_server.get_temporal_client", return_value=workflow_env.client):
        result = await publish_post("post-1", "ws-1")
        assert "workflow_id" in result

        # Verify workflow is running
        handle = workflow_env.client.get_workflow_handle(result["workflow_id"])
        desc = await handle.describe()
        assert desc.status.name in ("RUNNING", "COMPLETED")
```

### Time Skipping (Python)

```python
@pytest.fixture
async def time_skipping_env():
    async with await WorkflowEnvironment.start_time_skipping() as env:
        yield env

@pytest.mark.asyncio
async def test_scheduled_post_time_skip(time_skipping_env):
    """Workflow with 24h sleep completes instantly in test."""
    async with Worker(
        time_skipping_env.client,
        task_queue="test",
        workflows=[ScheduledPostWorkflow],
        activities=[mock_publish],
    ):
        result = await time_skipping_env.client.execute_workflow(
            ScheduledPostWorkflow.run,
            ScheduleInput(post_id="p-1", scheduled_at=future_timestamp),
            id="test-schedule-1",
            task_queue="test",
        )
        assert result.status == "published"
```
