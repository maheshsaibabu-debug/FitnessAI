import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
// sqlite3_flutter_libs has no Dart API to call — it's a pubspec-only
// dependency that bundles the native sqlite3 library for each platform.

import 'tables/accountability_tables.dart';
import 'tables/exercise_tables.dart';
import 'tables/health_tables.dart';
import 'tables/nutrition_tables.dart';
import 'tables/profile_tables.dart';
import 'tables/progress_tables.dart';
import 'tables/social_tables.dart';
import 'tables/sync_tables.dart';
import 'tables/workout_tables.dart';

part 'app_database.g.dart';

/// The local operational source of truth. Every table here is designed to
/// be fully queryable and writable with zero network access — see
/// docs/OFFLINE_FIRST.md for which app flows each table backs.
@DriftDatabase(
  tables: [
    UserProfiles,
    FitnessGoals,
    FitnessBaselines,
    Exercises,
    ExerciseProgressions,
    WorkoutPlans,
    Workouts,
    WorkoutExercises,
    WorkoutSets,
    WorkoutCompletions,
    StepRecords,
    CardioSessions,
    HiitSessions,
    WeightLogs,
    BodyCompositionLogs,
    MeasurementLogs,
    NutritionGoals,
    Foods,
    Meals,
    MealLogs,
    DailyPlans,
    DailyTasks,
    TaskCompletions,
    CoachEvents,
    CoachInsights,
    AppNotifications,
    NotificationPreferences,
    Achievements,
    AchievementUnlocks,
    PersonalRecords,
    Challenges,
    ChallengeParticipations,
    SyncQueueEntries,
    SyncMetadataEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  /// Test-only constructor for an in-memory database.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // Additive migrations only: new tables/columns via m.createTable /
          // m.addColumn per version bump. No destructive migrations against
          // user data without an explicit, documented backfill step.
        },
      );

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'fitness_companion.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
