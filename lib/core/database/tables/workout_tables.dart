import 'package:drift/drift.dart';

class WorkoutPlans extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get strategyNotes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

class Workouts extends Table {
  TextColumn get id => text()();
  TextColumn get planId => text().nullable()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get workoutType =>
      text()(); // strength_full_body|strength_upper|strength_lower|push|pull|legs|core|bodyweight|hiit|cardio
  DateTimeColumn get scheduledDate => dateTime()();
  IntColumn get estimatedMinutes => integer().nullable()();
  TextColumn get status =>
      text().withDefault(const Constant('scheduled'))(); // scheduled|in_progress|completed|partial|skipped
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class WorkoutExercises extends Table {
  TextColumn get id => text()();
  TextColumn get workoutId => text()();
  TextColumn get exerciseId => text()();
  IntColumn get orderIndex => integer()();
  IntColumn get targetSets => integer().nullable()();
  IntColumn get targetReps => integer().nullable()();
  RealColumn get targetWeightKg => real().nullable()();
  IntColumn get targetDurationSeconds => integer().nullable()();
  IntColumn get restSeconds => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class WorkoutSets extends Table {
  TextColumn get id => text()();
  TextColumn get workoutExerciseId => text()();
  IntColumn get setIndex => integer()();
  IntColumn get targetReps => integer().nullable()();
  IntColumn get actualReps => integer().nullable()();
  RealColumn get targetWeightKg => real().nullable()();
  RealColumn get actualWeightKg => real().nullable()();
  IntColumn get rpe => integer().nullable()();
  TextColumn get outcome => text().nullable()(); // completed|reduced|skipped
  TextColumn get eventId => text().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Idempotent event: "this workout was completed/partial/skipped". Keyed
/// by eventId so a retried sync upload never double-counts a completion.
class WorkoutCompletions extends Table {
  TextColumn get id => text()();
  TextColumn get workoutId => text()();
  TextColumn get userId => text()();
  TextColumn get status => text()(); // completed|partial|skipped|couldnt_complete
  TextColumn get skipReasonCode =>
      text().nullable()(); // no_time|too_tired|busy|sore|no_equipment|not_motivated|other
  TextColumn get feeling => text().nullable()(); // easy|good|challenging|very_difficult
  IntColumn get durationSeconds => integer().nullable()();
  TextColumn get eventId => text()();
  DateTimeColumn get completedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
