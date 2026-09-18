import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:fitness_companion/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies the local schema actually round-trips data — the core claim
/// of "SQLite/Drift working" in the product acceptance checklist. Uses an
/// in-memory database so it's fast and needs no device.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('user profile round-trips through Drift', () async {
    final now = DateTime.now().toUtc();
    await db.into(db.userProfiles).insert(UserProfilesCompanion.insert(
          id: 'user-1',
          name: 'Ada Lovelace',
          sex: 'female',
          createdAt: now,
          updatedAt: now,
        ));

    final row = await (db.select(db.userProfiles)..where((t) => t.id.equals('user-1'))).getSingle();
    expect(row.name, 'Ada Lovelace');
    expect(row.onboardingCompleted, isFalse);
  });

  test('sync queue enqueues and is queryable by status', () async {
    final now = DateTime.now().toUtc();
    await db.into(db.syncQueueEntries).insert(SyncQueueEntriesCompanion.insert(
          id: 'q1',
          eventId: 'evt-1',
          entityType: 'user_profile',
          entityId: 'user-1',
          operation: 'insert',
          payloadJson: '{}',
          createdAt: now,
        ));

    final pending =
        await (db.select(db.syncQueueEntries)..where((t) => t.status.equals('pending'))).get();
    expect(pending, hasLength(1));
    expect(pending.single.eventId, 'evt-1');
  });

  test('duplicate event_id in the outbox is rejected (idempotency at the schema level)', () async {
    final now = DateTime.now().toUtc();
    await db.into(db.syncQueueEntries).insert(SyncQueueEntriesCompanion.insert(
          id: 'q1',
          eventId: 'evt-dup',
          entityType: 'weight_log',
          entityId: 'w1',
          operation: 'insert',
          payloadJson: '{}',
          createdAt: now,
        ));

    expect(
      () => db.into(db.syncQueueEntries).insert(SyncQueueEntriesCompanion.insert(
            id: 'q2',
            eventId: 'evt-dup',
            entityType: 'weight_log',
            entityId: 'w2',
            operation: 'insert',
            payloadJson: '{}',
            createdAt: now,
          )),
      throwsA(anything),
    );
  });

  test('exercise progression is append-only across repeated inserts', () async {
    final base = DateTime.now().toUtc();
    for (var i = 0; i < 3; i++) {
      await db.into(db.exerciseProgressions).insert(ExerciseProgressionsCompanion.insert(
            id: 'p$i',
            userId: 'user-1',
            exerciseId: 'pull-up',
            recordedAt: base.add(Duration(days: i)),
            metricType: 'reps',
            value: (6 + i).toDouble(),
            eventId: 'evt-p$i',
            createdAt: base.add(Duration(days: i)),
          ));
    }

    final history = await (db.select(db.exerciseProgressions)
          ..where((t) => t.exerciseId.equals('pull-up'))
          ..orderBy([(t) => OrderingTerm.asc(t.recordedAt)]))
        .get();

    expect(history.map((e) => e.value), [6.0, 7.0, 8.0]);
  });
}
