import 'package:drift/native.dart';
import 'package:fitness_companion/core/database/app_database.dart';
import 'package:fitness_companion/core/database/database_provider.dart';
import 'package:fitness_companion/data/repositories/repository_providers.dart';
import 'package:fitness_companion/features/onboarding/application/onboarding_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises the full path a real onboarding submission takes: controller
/// -> ProfileRepository / WorkoutPlanRepository -> the deterministic
/// engines -> the real Drift schema. Uses `testWidgets` (not plain
/// `test`) purely to get a Flutter test binding, which is what makes
/// `rootBundle.loadString` (the exercise-library seed) work — no widgets
/// are actually pumped.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
  });

  tearDown(() async {
    container.dispose();
    // Must be awaited — see the comment in
    // workout_execution_integration_test.dart's tearDown for why an
    // unawaited close() here is a real cross-test race, not a nitpick.
    await db.close();
  });

  testWidgets('completing onboarding persists a profile, nutrition targets, and a generated first week',
      (tester) async {
    final controller = container.read(onboardingControllerProvider.notifier);

    controller.updateName('Ada Lovelace');
    controller.updateSex('female');
    controller.updateDateOfBirth(DateTime(1995, 3, 10));
    controller.updateHeightCm(165);
    controller.updateWeightKg(62);
    controller.toggleGoal('fat_loss');
    controller.updateLevelAndLocation(fitnessLevel: 'beginner', trainingLocation: 'home');
    controller.toggleEquipment('none');
    controller.updateAvailability(daysPerWeek: 3, minutesPerSession: 30, preferredTimeOfDay: 'morning');
    controller.updateDietaryPreference('omnivore');
    // Strong numbers relative to the self-reported "beginner" — the
    // baseline test result should override the self-report.
    controller.updateBaseline(pushUps: 30, squats: 35, pullUps: 5, plankSeconds: 90);

    final profileId = await controller.submit();

    final profile = await container.read(profileRepositoryProvider).activeProfileOnce();
    expect(profile, isNotNull);
    expect(profile!.id, profileId);
    expect(profile.onboardingCompleted, isTrue);
    expect(profile.name, 'Ada Lovelace');
    expect(profile.fitnessLevel, isNot('beginner'), reason: 'a strong baseline test should override the self-report');

    final goals = await db.select(db.fitnessGoals).get();
    expect(goals, hasLength(1));
    expect(goals.single.goalType, 'fat_loss');

    final baselines = await db.select(db.fitnessBaselines).get();
    expect(baselines, hasLength(1));
    expect(baselines.single.pushUpsReps, 30);

    final nutritionGoals = await db.select(db.nutritionGoals).get();
    expect(nutritionGoals, hasLength(1));
    expect(nutritionGoals.single.calorieTarget, greaterThan(0));
    expect(nutritionGoals.single.calculationMethod, 'mifflin_st_jeor');

    final weightLogs = await db.select(db.weightLogs).get();
    expect(weightLogs, hasLength(1));
    expect(weightLogs.single.weightKg, 62.0);

    final plans = await db.select(db.workoutPlans).get();
    expect(plans, hasLength(1));

    final workouts = await db.select(db.workouts).get();
    expect(workouts, hasLength(3)); // 3 days/week -> 3 full-body workouts

    final workoutExercises = await db.select(db.workoutExercises).get();
    expect(workoutExercises, isNotEmpty);
    for (final ex in workoutExercises) {
      final match = await (db.select(db.exercises)..where((e) => e.id.equals(ex.exerciseId))).getSingleOrNull();
      expect(match, isNotNull, reason: 'generated plan referenced an exercise not in the seeded library: ${ex.exerciseId}');
      // Equipment was set to bodyweight-only, so nothing generated should need gear.
      expect(match!.equipmentJson, contains('none'));
    }
  });

  testWidgets('submit rejects an incomplete draft instead of silently writing partial data', (tester) async {
    final controller = container.read(onboardingControllerProvider.notifier);
    controller.updateName('Incomplete');

    await expectLater(controller.submit(), throwsStateError);

    final profiles = await db.select(db.userProfiles).get();
    expect(profiles, isEmpty);
  });
}
