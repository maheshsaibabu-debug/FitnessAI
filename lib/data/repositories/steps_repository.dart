import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';

const _uuid = Uuid();

/// Local persistence for daily step totals. Unlike most tables here,
/// a day's step count is an upserted running total (source: healthkit |
/// health_connect | manual), not an append-only event — see
/// docs/SYNC_CONFLICTS.md for why that distinction matters for sync.
/// This repository owns the upsert-by-day logic since Drift has no
/// native unique constraint to lean on locally.
class StepsRepository {
  StepsRepository(this._db);

  final AppDatabase _db;

  Future<void> upsertSteps({
    required String userId,
    required int steps,
    required String source, // healthkit|health_connect|manual
    int? target,
    DateTime? date,
  }) async {
    final day = _truncate(date ?? DateTime.now());
    final now = DateTime.now().toUtc();

    final existing = await (_db.select(_db.stepRecords)
          ..where((s) => s.userId.equals(userId) & s.date.equals(day)))
        .getSingleOrNull();

    if (existing == null) {
      await _db.into(_db.stepRecords).insert(StepRecordsCompanion.insert(
            id: _uuid.v4(),
            userId: userId,
            date: day,
            steps: steps,
            target: Value(target),
            source: source,
            updatedAt: now,
          ));
    } else {
      await (_db.update(_db.stepRecords)..where((s) => s.id.equals(existing.id))).write(
        StepRecordsCompanion(
          steps: Value(steps),
          source: Value(source),
          target: Value(target ?? existing.target),
          updatedAt: Value(now),
        ),
      );
    }
  }

  Stream<StepRecord?> watchToday(String userId) {
    final day = _truncate(DateTime.now());
    return (_db.select(_db.stepRecords)..where((s) => s.userId.equals(userId) & s.date.equals(day)))
        .watchSingleOrNull();
  }

  Stream<List<StepRecord>> watchHistory(String userId, {int days = 7}) {
    final from = _truncate(DateTime.now()).subtract(Duration(days: days - 1));
    return (_db.select(_db.stepRecords)
          ..where((s) => s.userId.equals(userId) & s.date.isBiggerOrEqualValue(from))
          ..orderBy([(s) => OrderingTerm.asc(s.date)]))
        .watch();
  }

  /// One-shot equivalent of [watchHistory] — see ProfileRepository.goalsOnce.
  Future<List<StepRecord>> historyOnce(String userId, {int days = 7}) {
    final from = _truncate(DateTime.now()).subtract(Duration(days: days - 1));
    return (_db.select(_db.stepRecords)
          ..where((s) => s.userId.equals(userId) & s.date.isBiggerOrEqualValue(from))
          ..orderBy([(s) => OrderingTerm.asc(s.date)]))
        .get();
  }

  DateTime _truncate(DateTime d) => DateTime(d.year, d.month, d.day);
}
