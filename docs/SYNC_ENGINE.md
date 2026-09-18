# Sync Engine

## Flow

```
User Action
  -> local Drift write (same transaction as:)
  -> SyncQueueRepository.enqueue(...)          [lib/core/sync/sync_queue_repository.dart]
  -> UI renders immediately from the local write, does not wait for network
  -> ConnectivityStatus stream / app-resume / periodic timer triggers
  -> SyncEngine.drainQueue()                    [lib/core/sync/sync_engine.dart]
  -> Supabase upsert, keyed by the entity's idempotency column
```

The UI layer never calls Supabase directly for core fitness data. Repositories write to Drift and enqueue a sync entry; nothing in a widget's build method or event handler awaits a network call for functionality listed in docs/OFFLINE_FIRST.md.

## Outbox schema

`sync_queue_entries` (see `lib/core/database/tables/sync_tables.dart`): `id`, `event_id` (unique, client-generated), `entity_type`, `entity_id`, `operation` (insert|update|delete), `payload_json`, `created_at`, `attempt_count`, `last_attempt_at`, `status` (pending|in_flight|done|failed), `error`.

## Table routing

`lib/core/sync/sync_event_type.dart` holds `syncTableMappings`: for each `entity_type`, which Supabase table it upserts into, which column dedupe/upsert keys on, and whether duplicates are ignored (append-only events) or upserted (mutable singletons and the daily step total). This is the single place that encodes "how does this entity type resolve on conflict" for the transport layer — the *policy* rationale lives in [SYNC_CONFLICTS.md](SYNC_CONFLICTS.md).

## Failure handling

- Each entry retries with exponential backoff (`2^attempt` seconds, capped at 5 minutes), computed from `attempt_count` / `last_attempt_at` — no fixed retry timer that could hammer the server.
- After 8 attempts, an entry is left in `failed` state and skipped by future drains rather than retried forever; it stays visible in the sync status screen (`status = failed`) instead of silently disappearing, so the user isn't left thinking something synced when it didn't.
- `in_flight` rows found at the start of a drain are reset to `pending` (`recoverInterrupted`) — this is what makes an app kill mid-upload safe: an entry either finishes and becomes `done`/`failed`, or it goes back to `pending` and is retried, never left stuck.

## Triggers

The engine is invoked, not polling on its own:
1. Connectivity regained (`ConnectivityStatus` provider transitions false -> true).
2. App resumed from background.
3. A periodic background timer (interval TBD by battery testing — starts at 15 min) as a safety net in case the above two are missed.

## Idempotency

Every entity type with an `event_id` column relies on a Postgres `unique` constraint on that column (see `supabase/migrations/00000000000001_init.sql`) plus `upsert(..., onConflict: 'event_id', ignoreDuplicates: true)` client-side. A retried upload after a dropped connection is therefore a guaranteed no-op on the server, not a potential duplicate.
