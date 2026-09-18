import 'package:drift/drift.dart';

/// Bundled locally (seeded from assets/data/exercises.json on first launch)
/// so the exercise library works with zero network access.
class Exercises extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get category =>
      text()(); // strength|bodyweight|hiit|cardio|mobility|core
  TextColumn get primaryMusclesJson => text().withDefault(const Constant('[]'))();
  TextColumn get secondaryMusclesJson => text().withDefault(const Constant('[]'))();
  TextColumn get equipmentJson => text().withDefault(const Constant('[]'))();
  TextColumn get difficulty => text()(); // beginner|intermediate|advanced
  TextColumn get instructions => text()();
  TextColumn get formCuesJson => text().withDefault(const Constant('[]'))();
  TextColumn get commonMistakesJson => text().withDefault(const Constant('[]'))();
  TextColumn get beginnerVariantId => text().nullable()();
  TextColumn get advancedVariantId => text().nullable()();
  TextColumn get progressionId => text().nullable()();
  TextColumn get regressionId => text().nullable()();
  BoolColumn get isBundled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Append-only historical performance stream for an exercise. Never
/// mutated in place — the progression engine reads the tail of this
/// stream, it does not overwrite a "current" value.
class ExerciseProgressions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get exerciseId => text()();
  DateTimeColumn get recordedAt => dateTime()();
  TextColumn get metricType => text()(); // reps|weight_kg|duration_seconds|distance_m
  RealColumn get value => real()();
  IntColumn get rpe => integer().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get eventId => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
