import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';

const _uuid = Uuid();

/// The write side of the outbox. Every mutation that must reach Supabase
/// calls [enqueue] in the same local transaction as the domain write, so
/// the outbox entry and the data it describes are never inconsistent with
/// each other (see docs/SYNC_ENGINE.md).
class SyncQueueRepository {
  SyncQueueRepository(this._db);

  final AppDatabase _db;

  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required String operation, // insert|update|delete
    required Map<String, Object?> payload,
    String? eventId,
  }) {
    return _db.into(_db.syncQueueEntries).insert(
          SyncQueueEntriesCompanion.insert(
            id: _uuid.v4(),
            eventId: eventId ?? _uuid.v4(),
            entityType: entityType,
            entityId: entityId,
            operation: operation,
            payloadJson: jsonEncode(payload),
            createdAt: DateTime.now().toUtc(),
          ),
        );
  }

  Future<List<SyncQueueEntry>> pending({int limit = 25}) {
    return (_db.select(_db.syncQueueEntries)
          ..where((t) => t.status.isIn(['pending', 'failed']))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<void> markInFlight(String id) => _updateStatus(id, 'in_flight');

  Future<void> markDone(String id) => _updateStatus(id, 'done');

  Future<void> markFailed(String id, String error) async {
    final entry = await (_db.select(_db.syncQueueEntries)..where((t) => t.id.equals(id)))
        .getSingle();
    await (_db.update(_db.syncQueueEntries)..where((t) => t.id.equals(id))).write(
      SyncQueueEntriesCompanion(
        status: const Value('failed'),
        error: Value(error),
        attemptCount: Value(entry.attemptCount + 1),
        lastAttemptAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> _updateStatus(String id, String status) {
    return (_db.update(_db.syncQueueEntries)..where((t) => t.id.equals(id))).write(
      SyncQueueEntriesCompanion(
        status: Value(status),
        lastAttemptAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// Rows stuck `in_flight` from a process kill mid-upload are recovered
  /// back to `pending` on next app start (see the "app termination during
  /// sync" scenario in docs/TEST_PLAN.md).
  Future<void> recoverInterrupted() {
    return (_db.update(_db.syncQueueEntries)..where((t) => t.status.equals('in_flight')))
        .write(const SyncQueueEntriesCompanion(status: Value('pending')));
  }
}
