import 'package:drift/native.dart';
import 'package:fitness_companion/ai/ai_providers.dart';
import 'package:fitness_companion/core/database/app_database.dart';
import 'package:fitness_companion/core/database/database_provider.dart';
import 'package:fitness_companion/data/repositories/repository_providers.dart';
import 'package:fitness_companion/features/onboarding/application/onboarding_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// docs/AI_ARCHITECTURE.md's FitnessContextResolver against a real
/// (in-memory) database — confirms it only ever summarizes data that's
/// actually there, and never crashes on a brand-new profile with no
/// workout/weight/step history yet.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  testWidgets('returns null when onboarding has not been completed', (tester) async {
    final context = await container.read(fitnessContextResolverProvider).resolve();
    expect(context, isNull);
  });

  testWidgets('summarizes a real profile, then reflects a completed workout in adherence and streak',
      (tester) async {
    final onboarding = container.read(onboardingControllerProvider.notifier);
    onboarding.updateName('Omar');
    onboarding.updateSex('male');
    onboarding.updateDateOfBirth(DateTime(1990, 1, 1));
    onboarding.updateHeightCm(180);
    onboarding.updateWeightKg(85);
    onboarding.toggleGoal('strength');
    onboarding.updateLevelAndLocation(fitnessLevel: 'intermediate', trainingLocation: 'home');
    onboarding.toggleEquipment('none');
    onboarding.updateAvailability(daysPerWeek: 3, minutesPerSession: 30);
    await onboarding.submit();

    final freshContext = await container.read(fitnessContextResolverProvider).resolve();
    expect(freshContext, isNotNull);
    expect(freshContext!.name, 'Omar');
    expect(freshContext.goals, contains('strength'));
    expect(freshContext.fitnessLevel, 'intermediate');
    expect(freshContext.currentStreak, 0);
    expect(freshContext.workoutsCompletedLast14Days, 0);
    // The plan starts today, so a workout is already scheduled next.
    expect(freshContext.nextWorkoutTitle, isNotNull);
    expect(freshContext.calorieTarget, greaterThan(0));
    // No weight history beyond the single onboarding entry -> no trend yet.
    expect(freshContext.weightTrendKgPerWeek, isNull);

    final profile = await container.read(profileRepositoryProvider).activeProfileOnce();
    final workouts = await db.select(db.workouts).get();
    final todaysWorkout = workouts.first;

    await container.read(workoutExecutionRepositoryProvider).completeWorkout(
          workoutId: todaysWorkout.id,
          userId: profile!.id,
          status: 'completed',
          feeling: 'good',
        );

    final afterContext = await container.read(fitnessContextResolverProvider).resolve();
    expect(afterContext!.workoutsCompletedLast14Days, 1);
    expect(afterContext.currentStreak, 1);
    expect(afterContext.lastWorkoutStatus, 'completed');
  });
}
