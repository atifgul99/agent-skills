# Temporal MCP Integration Reference

## Table of Contents

1. [Overview](#overview)
2. [Temporal MCP Server](#temporal-mcp-server)
3. [Durable MCP Tools Pattern](#durable-mcp-tools-pattern)
4. [Long-Running Interactive MCP Tools](#long-running-interactive-mcp-tools)
5. [Architecture Patterns](#architecture-patterns)
6. [MCP Tool Definition Examples](#mcp-tool-definition-examples)

---

## Overview

Temporal + MCP integration serves two purposes:

1. **Temporal MCP Server**: An MCP server that exposes Temporal operations as tools, letting AI
   assistants manage workflows conversationally (start, signal, query, cancel, list, schedule).
2. **Durable MCP Tools**: Implementing MCP tools as Temporal workflows for durability, reliability,
   and long-running capability. The tool triggers a workflow; the workflow does the actual work.

Source: [Temporal MCP Server](https://temporal.io/code-exchange/temporal-mcp-server) |
[Durable MCP Blog](https://temporal.io/blog/durable-mcp-how-to-give-agentic-systems-superpowers) |
[Long-Running MCP Blog](https://temporal.io/blog/building-long-running-interactive-mcp-tools-temporal) |
[Google: Durable AI agent with Gemini + Temporal (no-MCP, direct ReAct loop)](https://ai.google.dev/gemini-api/docs/temporal-example)

---

## Temporal MCP Server

The official [Temporal MCP Server](https://temporal.io/code-exchange/temporal-mcp-server) bridges
AI assistants (Claude, Copilot, Cursor, etc.) and a Temporal cluster. It exposes 19 tools covering:

- **Workflow lifecycle**: start, describe, query, signal, cancel, terminate, reset
- **Batch operations**: bulk cancel, bulk terminate, bulk signal
- **Schedule management**: create, describe, pause, unpause, trigger, delete
- **Search**: list workflows with query filters

### Setup

The MCP server runs as a Python process. Add to your MCP client config:

```json
{
  "mcpServers": {
    "temporal": {
      "command": "uvx",
      "args": ["temporal-mcp-server"],
      "env": {
        "TEMPORAL_ADDRESS": "localhost:7233",
        "TEMPORAL_NAMESPACE": "default"
      }
    }
  }
}
```

For Temporal Cloud:

```json
{
  "mcpServers": {
    "temporal": {
      "command": "uvx",
      "args": ["temporal-mcp-server"],
      "env": {
        "TEMPORAL_ADDRESS": "postbuzz-prod.tmprl.cloud:7233",
        "TEMPORAL_NAMESPACE": "postbuzz-prod",
        "TEMPORAL_API_KEY": "<your-api-key>"
      }
    }
  }
}
```

For mTLS auth, set `TEMPORAL_TLS_CERT` and `TEMPORAL_TLS_KEY` env vars instead of API key.

### What It Enables

- "Start the publish-post workflow for post-123" → AI calls `start_workflow` tool
- "What's the status of the campaign workflow?" → AI calls `describe_workflow` tool
- "Cancel all stuck workflows from yesterday" → AI calls `batch_cancel` tool
- "Show me the schedule for daily analytics sync" → AI calls `describe_schedule` tool
- "Trigger the analytics sync early for testing" → AI calls `trigger_schedule` tool

The AI assistant handles natural language → tool parameter mapping. No CLI knowledge needed.

---

## Durable MCP Tools Pattern

Instead of MCP tools doing work directly (fragile, no retry, timeout-limited), implement them
as Temporal workflow starters. The MCP tool starts a workflow; Temporal handles execution.

### Why

| Problem with raw MCP tools                   | Temporal solution                    |
| -------------------------------------------- | ------------------------------------ |
| MCP client disconnects → tool fails silently | Workflow continues independently     |
| No automatic retry on failure                | Built-in retry policies per activity |
| Limited execution time                       | Workflows run for days/weeks/months  |
| No visibility into progress                  | Queries, signals, Web UI             |
| No state persistence                         | Event-sourced, crash-proof           |
| Hard to compose multiple steps               | Workflow orchestrates activities     |

### Basic Pattern (Python — MCP SDK is primarily Python)

```python
from mcp.server.fastmcp import FastMCP
from temporalio.client import Client

mcp = FastMCP("my-durable-tools")

async def get_temporal_client() -> Client:
    return await Client.connect(
        os.environ.get("TEMPORAL_ADDRESS", "localhost:7233"),
        namespace=os.environ.get("TEMPORAL_NAMESPACE", "default"),
    )

@mcp.tool()
async def publish_post(post_id: str, workspace_id: str) -> dict:
    """Publish a social media post to all connected platforms. Handles media upload,
    platform API calls, and user notification with automatic retries."""
    client = await get_temporal_client()
    handle = await client.start_workflow(
        "publishPostWorkflow",
        {"postId": post_id, "workspaceId": workspace_id},
        id=f"publish-post-{workspace_id}-{post_id}",
        task_queue="post-processing",
    )
    return {"workflow_id": handle.id, "run_id": handle.result_run_id, "status": "started"}
```

The workflow runs on your Temporal workers (TypeScript or Python). The MCP tool just starts it
and returns the handle. The AI can then use a separate `check_status` tool to poll progress.

### TypeScript Variant (via custom MCP server)

If building an MCP server in TypeScript:

```typescript
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js'
import { getTemporalClient } from './temporal/client'

const server = new McpServer({ name: 'postbuzz-temporal', version: '1.0.0' })

server.tool('publishPost', { postId: 'string', workspaceId: 'string' }, async ({ postId, workspaceId }) => {
  const client = await getTemporalClient()
  const handle = await client.workflow.start('publishPostWorkflow', {
    taskQueue: 'post-processing',
    workflowId: `publish-post-${workspaceId}-${postId}`,
    args: [{ postId, workspaceId }],
  })
  return { content: [{ type: 'text', text: JSON.stringify({ workflowId: handle.workflowId, status: 'started' }) }] }
})
```

---

## Long-Running Interactive MCP Tools

The most powerful pattern: multiple MCP tools that interact with the same long-running workflow.

### The Invoice Pattern (from Temporal blog)

```
┌──────────────────────────────────────────────────────┐
│                    AI Assistant                        │
│                                                        │
│  1. "Process this invoice"  ──▶  trigger() tool       │
│  2. "What's the status?"    ──▶  status() tool        │
│  3. "Approve it"            ──▶  approve() tool       │
│  4. "What happened?"        ──▶  status() tool        │
│                                                        │
└──────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────┐
│               Temporal Workflow                        │
│                                                        │
│  PENDING → VALIDATING → PENDING_APPROVAL → APPROVED   │
│                              ▲                         │
│                              │ signal                  │
│                         wait_condition()               │
│                         (up to 5 days)                 │
└──────────────────────────────────────────────────────┘
```

### Implementation (Python MCP Tools)

```python
@mcp.tool()
async def trigger_campaign(campaign_id: str, workspace_id: str) -> dict:
    """Start campaign execution workflow. Returns workflow ID for status tracking."""
    client = await get_temporal_client()
    handle = await client.start_workflow(
        "campaignExecutionWorkflow",
        {"campaignId": campaign_id, "workspaceId": workspace_id},
        id=f"campaign-{workspace_id}-{campaign_id}",
        task_queue="campaign-management",
    )
    return {"workflow_id": handle.id, "run_id": handle.result_run_id}


@mcp.tool()
async def campaign_status(workflow_id: str) -> str:
    """Check current status of a campaign execution workflow."""
    client = await get_temporal_client()
    handle = client.get_workflow_handle(workflow_id)
    desc = await handle.describe()
    status = await handle.query("getStatus")
    return f"Campaign {workflow_id}: {status} (workflow: {desc.status.name})"


@mcp.tool()
async def approve_campaign(workflow_id: str, approved_by: str) -> str:
    """Approve a campaign that's pending review. Sends approval signal to workflow."""
    client = await get_temporal_client()
    handle = client.get_workflow_handle(workflow_id)
    await handle.signal("approval", {"approved": True, "approvedBy": approved_by})
    return "Approval signal sent"


@mcp.tool()
async def pause_campaign(workflow_id: str, reason: str) -> str:
    """Pause a running campaign. Can be resumed later."""
    client = await get_temporal_client()
    handle = client.get_workflow_handle(workflow_id)
    await handle.signal("pause", {"reason": reason})
    return f"Pause signal sent: {reason}"
```

### Corresponding Workflow (TypeScript)

```typescript
export const approvalSignal = defineSignal<[{ approved: boolean; approvedBy: string }]>('approval')
export const pauseSignal = defineSignal<[{ reason: string }]>('pause')
export const statusQuery = defineQuery<string>('getStatus')

export async function campaignExecutionWorkflow(input: CampaignInput): Promise<CampaignResult> {
  let status = 'initializing'
  let paused = false
  let approval: { approved: boolean; approvedBy: string } | undefined

  setHandler(statusQuery, () => status)
  setHandler(approvalSignal, (data) => {
    approval = data
  })
  setHandler(pauseSignal, ({ reason }) => {
    paused = true
    log.info('Campaign paused', { reason })
  })

  status = 'validating'
  await validateCampaign(input)

  status = 'pending_approval'
  const wasApproved = await condition(() => approval !== undefined, '7d')
  if (!wasApproved || !approval?.approved) {
    return { status: 'rejected', campaignId: input.campaignId }
  }

  status = 'executing'
  for (const post of input.posts) {
    // Check pause between posts
    if (paused) {
      status = 'paused'
      await condition(() => !paused) // Wait for unpause signal
      status = 'executing'
    }
    await publishPost(post)
  }

  status = 'completed'
  return { status: 'completed', campaignId: input.campaignId }
}
```

---

## Architecture Patterns

### Pattern 1: MCP Server as Workflow Gateway

```
AI Assistant ──MCP──▶ MCP Server ──gRPC──▶ Temporal Cloud
                          │                      │
                     start/signal/query      persist + schedule
                                                  │
                                                  ▼
                                            Temporal Workers
                                           (VPS / Container)
```

Best for: Operational tools (start, check, approve, cancel workflows from AI).

### Pattern 2: Next.js API → Temporal → MCP for Monitoring

```
Browser UI ──HTTP──▶ Next.js API ──gRPC──▶ Temporal Cloud
                                               │
AI Assistant ──MCP──▶ Temporal MCP Server ─────┘
                     (read-only ops monitoring)
```

Best for: App triggers workflows via API routes; AI assists with monitoring and ops.

### Pattern 3: Full Agentic (AI Orchestrates Everything)

```
AI Agent ──MCP──▶ Tool A (Temporal Workflow) ──▶ External API
    │
    ├──MCP──▶ Tool B (Temporal Workflow) ──▶ Database
    │
    └──MCP──▶ Tool C (Temporal Workflow) ──▶ Another Service
```

Best for: AI-driven automation where agent decides which workflows to trigger based on goals.

---

## MCP Tool Definition Examples

### PostBuzz-Specific Tools

```python
@mcp.tool()
async def schedule_post(post_id: str, workspace_id: str, scheduled_at: str) -> dict:
    """Schedule a social media post for future publication. The workflow will sleep
    until the scheduled time, then publish to all connected platforms."""
    client = await get_temporal_client()
    handle = await client.start_workflow(
        "scheduledPostWorkflow",
        {"postId": post_id, "workspaceId": workspace_id, "scheduledAt": scheduled_at},
        id=f"scheduled-post-{workspace_id}-{post_id}",
        task_queue="post-processing",
    )
    return {"workflow_id": handle.id, "status": "scheduled"}


@mcp.tool()
async def cancel_scheduled_post(workflow_id: str) -> str:
    """Cancel a previously scheduled post before it publishes."""
    client = await get_temporal_client()
    handle = client.get_workflow_handle(workflow_id)
    await handle.signal("cancel")
    return "Cancellation signal sent"


@mcp.tool()
async def reschedule_post(workflow_id: str, new_scheduled_at: str) -> str:
    """Reschedule a post to a different time."""
    client = await get_temporal_client()
    handle = client.get_workflow_handle(workflow_id)
    await handle.signal("reschedule", {"scheduledAt": new_scheduled_at})
    return f"Rescheduled to {new_scheduled_at}"


@mcp.tool()
async def list_scheduled_posts(workspace_id: str) -> list:
    """List all currently scheduled posts for a workspace."""
    client = await get_temporal_client()
    workflows = []
    async for wf in client.list_workflows(
        f'WorkflowType = "scheduledPostWorkflow" AND ExecutionStatus = "Running" '
        f'AND WorkflowId STARTS_WITH "scheduled-post-{workspace_id}"'
    ):
        workflows.append({
            "workflow_id": wf.id,
            "start_time": str(wf.start_time),
            "status": wf.status.name,
        })
    return workflows
```
