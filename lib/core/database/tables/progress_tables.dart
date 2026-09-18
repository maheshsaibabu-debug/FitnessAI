import 'package:drift/drift.dart';

class Achievements extends Table {
  TextColumn get id => text()();
  TextColumn get key => text().unique()(); // stable code, e.g. "streak_7"
  TextColumn get title => text()();
  TextColumn get description => text()();
  TextColumn get icon => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class AchievementUnlocks extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get achievementId => text()();
  TextColumn get eventId => text()();
  DateTimeColumn get unlockedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class PersonalRecords extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get recordType =>
      text()(); // max_pull_ups|max_push_ups|plank_seconds|squat_1rm|bench_1rm|deadlift_1rm|run_distance|run_time|weekly_steps|exercise_specific
  TextColumn get exerciseId => text().nullable()();
  RealColumn get value => real()();
  TextColumn get unit => text()();
  TextColumn get eventId => text()();
  DateTimeColumn get recordedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
