# Temporal Python SDK Reference

## Table of Contents

1. [Installation](#installation)
2. [Workflow Definition](#workflow-definition)
3. [Activity Definition](#activity-definition)
4. [Worker Setup](#worker-setup)
5. [Client Usage](#client-usage)
6. [Signals, Queries, Updates](#signals-queries-updates)
7. [Saga Pattern](#saga-pattern)
8. [Error Handling](#error-handling)
9. [Schedules](#schedules)

---

## Installation

```bash
pip install temporalio
# or
poetry add temporalio
# or
uv add temporalio
```

Requires Python >= 3.8. Recommended: Python 3.11+.

---

## Workflow Definition

```python
from temporalio import workflow
from temporalio.common import RetryPolicy
from datetime import timedelta
from dataclasses import dataclass

@dataclass
class PublishInput:
    post_id: str
    workspace_id: str
    content: str
    platform_channels: list[dict]
    scheduled_at: int  # Unix timestamp ms
    media_ids: list[str]

@dataclass
class PublishResult:
    status: str
    post_id: str
    platform_results: list[dict] | None = None

@workflow.defn
class PublishPostWorkflow:
    def __init__(self):
        self._status = "initializing"
        self._cancelled = False

    @workflow.run
    async def run(self, input: PublishInput) -> PublishResult:
        self._status = "preparing"

        # Wait until scheduled time
        now_ms = int(workflow.now().timestamp() * 1000)
        if input.scheduled_at > now_ms:
            wait_seconds = (input.scheduled_at - now_ms) / 1000
            cancelled = await workflow.wait_condition(
                lambda: self._cancelled, timeout=timedelta(seconds=wait_seconds)
            )
            if cancelled:
                return PublishResult(status="cancelled", post_id=input.post_id)

        self._status = "uploading_media"
        media_urls = []
        if input.media_ids:
            media_urls = await workflow.execute_activity(
                upload_media,
                {"post_id": input.post_id, "media_ids": input.media_ids},
                start_to_close_timeout=timedelta(minutes=5),
                heartbeat_timeout=timedelta(seconds=30),
            )

        self._status = "publishing"
        import asyncio
        results = await asyncio.gather(*[
            workflow.execute_activity(
                publish_to_platform,
                {"post_id": input.post_id, "channel": ch, "content": input.content, "media_urls": media_urls},
                start_to_close_timeout=timedelta(seconds=30),
                retry_policy=RetryPolicy(
                    maximum_attempts=3,
                    initial_interval=timedelta(seconds=1),
                    non_retryable_error_types=["AuthError"],
                ),
            )
            for ch in input.platform_channels
        ])

        self._status = "completed"
        return PublishResult(status="published", post_id=input.post_id, platform_results=list(results))

    @workflow.query
    def get_status(self) -> str:
        return self._status

    @workflow.signal
    async def cancel(self):
        self._cancelled = True
```

Key rules:
- `@workflow.defn` on the class, `@workflow.run` on the main method.
- State is instance attributes — survives replay.
- `workflow.now()` instead of `datetime.now()` (deterministic).
- `workflow.execute_activity()` for calling activities.
- `workflow.wait_condition(fn, timeout)` blocks until fn is True or timeout.

---

## Activity Definition

```python
from temporalio import activity
from temporalio.exceptions import ApplicationError
import httpx

@activity.defn
async def publish_to_platform(input: dict) -> dict:
    activity.logger.info(f"Publishing to {input['channel']['platform']}")

    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"https://api.{input['channel']['platform']}.com/posts",
            json={"content": input["content"], "media": input["media_urls"]},
            headers={"Authorization": f"Bearer {get_token(input['channel']['platform'])}"},
        )
        if response.status_code == 401:
            raise ApplicationError("Auth failed", non_retryable=True, type="AuthError")
        response.raise_for_status()
        return response.json()


@activity.defn
async def upload_media(input: dict) -> list[str]:
    urls = []
    for i, media_id in enumerate(input["media_ids"]):
        activity.heartbeat(f"Uploading {i+1}/{len(input['media_ids'])}")
        url = await process_and_upload(media_id)
        urls.append(url)
    return urls
```

Key rules:
- `@activity.defn` decorator on the function.
- `activity.heartbeat(details)` for long-running activities.
- `activity.logger` for structured logging.
- Raise `ApplicationError(msg, non_retryable=True)` to stop retries.

---

## Worker Setup

```python
import asyncio
import os
from temporalio.client import Client
from temporalio.worker import Worker

async def main():
    client = await Client.connect(
        os.environ.get("TEMPORAL_ADDRESS", "localhost:7233"),
        namespace=os.environ.get("TEMPORAL_NAMESPACE", "default"),
        # For Temporal Cloud with API key:
        # rpc_metadata={"temporal-namespace": namespace},
        # api_key=os.environ["TEMPORAL_API_KEY"],
        # tls=True,
    )

    worker = Worker(
        client,
        task_queue="post-processing",
        workflows=[PublishPostWorkflow],
        activities=[publish_to_platform, upload_media, notify_user],
    )

    print("Worker started, polling task queue: post-processing")
    await worker.run()

if __name__ == "__main__":
    asyncio.run(main())
```

---

## Client Usage

```python
from temporalio.client import Client

async def start_publish(post_id: str, workspace_id: str):
    client = await Client.connect("localhost:7233")

    # Start and get handle
    handle = await client.start_workflow(
        PublishPostWorkflow.run,
        PublishInput(post_id=post_id, workspace_id=workspace_id, ...),
        id=f"publish-post-{workspace_id}-{post_id}",
        task_queue="post-processing",
    )
    return handle.id

    # Or start and wait for result
    result = await client.execute_workflow(
        PublishPostWorkflow.run,
        input_data,
        id=f"publish-{post_id}",
        task_queue="post-processing",
    )

    # Query existing workflow
    handle = client.get_workflow_handle(f"publish-{post_id}")
    status = await handle.query(PublishPostWorkflow.get_status)

    # Signal existing workflow
    await handle.signal(PublishPostWorkflow.cancel)
```

---

## Signals, Queries, Updates

```python
@workflow.defn
class ApprovalWorkflow:
    def __init__(self):
        self._approved: bool | None = None
        self._status = "pending"

    @workflow.run
    async def run(self, input: ApprovalInput) -> str:
        self._status = "awaiting_approval"
        approved = await workflow.wait_condition(
            lambda: self._approved is not None,
            timeout=timedelta(days=5),
        )
        if not approved:
            return "timed_out"
        return "approved" if self._approved else "rejected"

    @workflow.signal
    async def approve(self, approved: bool):
        self._approved = approved
        self._status = "approved" if approved else "rejected"

    @workflow.query
    def get_status(self) -> str:
        return self._status

    @workflow.update
    async def add_note(self, note: str) -> int:
        self._notes.append(note)
        return len(self._notes)

    @add_note.validator
    def validate_note(self, note: str):
        if len(note) > 1000:
            raise ValueError("Note too long")
```

---

## Saga Pattern

```python
@workflow.defn
class OrderSagaWorkflow:
    @workflow.run
    async def run(self, order: OrderInput) -> OrderResult:
        compensations: list[tuple] = []

        try:
            reservation = await workflow.execute_activity(
                reserve_inventory, order.items,
                start_to_close_timeout=timedelta(minutes=2),
            )
            compensations.append((release_inventory, reservation.id))

            payment = await workflow.execute_activity(
                charge_payment, PaymentInput(order_id=order.id, amount=order.total),
                start_to_close_timeout=timedelta(minutes=5),
            )
            compensations.append((refund_payment, payment.id))

            shipment = await workflow.execute_activity(
                create_shipment, ShipmentInput(order_id=order.id),
                start_to_close_timeout=timedelta(minutes=3),
            )
            return OrderResult(status="completed", order_id=order.id)

        except Exception:
            workflow.logger.warning(f"Saga failed, running {len(compensations)} compensations")
            for compensate_fn, compensate_arg in reversed(compensations):
                try:
                    await workflow.execute_activity(
                        compensate_fn, compensate_arg,
                        start_to_close_timeout=timedelta(minutes=2),
                    )
                except Exception as e:
                    workflow.logger.error(f"Compensation failed: {e}")
            raise
```

---

## Error Handling

```python
from temporalio.exceptions import ApplicationError

# Non-retryable error (e.g., validation failure)
raise ApplicationError("Invalid input", non_retryable=True, type="ValidationError")

# Retryable error (default — just raise normally)
raise RuntimeError("Temporary API failure")

# In activity — check for cancellation
if activity.is_cancelled():
    raise asyncio.CancelledError()
```

---

## Schedules

```python
from temporalio.client import Client, Schedule, ScheduleActionStartWorkflow, ScheduleSpec, ScheduleIntervalSpec

client = await Client.connect("localhost:7233")

# Create recurring schedule
await client.create_schedule(
    "daily-analytics-sync",
    Schedule(
        action=ScheduleActionStartWorkflow(
            SyncAnalyticsWorkflow.run,
            {"source": "all_platforms"},
            id="analytics-sync",
            task_queue="analytics-sync",
        ),
        spec=ScheduleSpec(
            cron_expressions=["0 2 * * *"],  # 2 AM daily
        ),
    ),
)

# Manage schedule
handle = client.get_schedule_handle("daily-analytics-sync")
await handle.pause("Maintenance")
await handle.unpause()
await handle.trigger()  # Run immediately
await handle.delete()
```
