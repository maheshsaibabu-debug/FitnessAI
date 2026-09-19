import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';

const _uuid = Uuid();

/// Weight is a time-series log — every entry survives (see
/// docs/SYNC_CONFLICTS.md), so this is a plain append, never an update.
class WeightRepository {
  WeightRepository(this._db);

  final AppDatabase _db;

  Future<void> logWeight({required String userId, required double weightKg, DateTime? recordedAt}) {
    final now = DateTime.now().toUtc();
    return _db.into(_db.weightLogs).insert(WeightLogsCompanion.insert(
          id: _uuid.v4(),
          userId: userId,
          weightKg: weightKg,
          recordedAt: recordedAt ?? now,
          eventId: _uuid.v4(),
          createdAt: now,
        ));
  }

  Stream<WeightLog?> watchLatest(String userId) {
    return (_db.select(_db.weightLogs)
          ..where((w) => w.userId.equals(userId))
          ..orderBy([(w) => OrderingTerm.desc(w.recordedAt)])
          ..limit(1))
        .watchSingleOrNull();
  }

  Stream<List<WeightLog>> watchHistory(String userId, {int days = 30}) {
    final from = DateTime.now().subtract(Duration(days: days));
    return (_db.select(_db.weightLogs)
          ..where((w) => w.userId.equals(userId) & w.recordedAt.isBiggerOrEqualValue(from))
          ..orderBy([(w) => OrderingTerm.asc(w.recordedAt)]))
        .watch();
  }
}
