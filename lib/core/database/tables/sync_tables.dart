import 'package:drift/drift.dart';

/// The outbox. Every local mutation that must reach Supabase enqueues a
/// row here instead of calling the network directly. The SyncEngine drains
/// this table in FIFO order whenever connectivity allows; this table is
/// itself never synced.
class SyncQueueEntries extends Table {
  TextColumn get id => text()();

  /// Client-generated, globally unique. Carried through to the server so
  /// a retried upload is a no-op there (see docs/SYNC_CONFLICTS.md).
  TextColumn get eventId => text().unique()();

  TextColumn get entityType => text()(); // e.g. "workout_completion"
  TextColumn get entityId => text()();
  TextColumn get operation => text()(); // insert|update|delete
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  TextColumn get status =>
      text().withDefault(const Constant('pending'))(); // pending|in_flight|done|failed
  TextColumn get error => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-entity-type sync bookkeeping (last successful pull cursor, etc.)
/// for pulling remote changes down to the device.
class SyncMetadataEntries extends Table {
  TextColumn get entityType => text()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  TextColumn get lastCursor => text().nullable()();

  @override
  Set<Column> get primaryKey => {entityType};
}
