import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/repositories/repository_providers.dart';
import '../../../data/repositories/workout_plan_repository.dart';
import '../../../domain/workout_engine/workout_generation_engine.dart';
import '../domain/onboarding_draft.dart';

part 'onboarding_controller.g.dart';

@Riverpod(keepAlive: true)
class OnboardingController extends _$OnboardingController {
  @override
  OnboardingDraft build() => const OnboardingDraft();

  void updateName(String name) => state = state.copyWith(name: name);

  void updateSex(String sex) => state = state.copyWith(sex: sex);

  void updateDateOfBirth(DateTime dateOfBirth) => state = state.copyWith(dateOfBirth: dateOfBirth);

  void updateHeightCm(double heightCm) => state = state.copyWith(heightCm: heightCm);

  void updateWeightKg(double weightKg) => state = state.copyWith(weightKg: weightKg);

  void toggleGoal(String goal) {
    final next = {...state.goals};
    next.contains(goal) ? next.remove(goal) : next.add(goal);
    state = state.copyWith(goals: next);
  }

  void updateLevelAndLocation({required String fitnessLevel, required String trainingLocation}) {
    state = state.copyWith(fitnessLevel: fitnessLevel, trainingLocation: trainingLocation);
  }

  void toggleEquipment(String equipment) {
    final next = {...state.equipment};
    next.contains(equipment) ? next.remove(equipment) : next.add(equipment);
    state = state.copyWith(equipment: next);
  }

  void updateAvailability({required int daysPerWeek, required int minutesPerSession, String? preferredTimeOfDay}) {
    state = state.copyWith(
      availabilityDaysPerWeek: daysPerWeek,
      availabilityMinutesPerSession: minutesPerSession,
      preferredTimeOfDay: preferredTimeOfDay,
    );
  }

  void updateDietaryPreference(String preference) => state = state.copyWith(dietaryPreference: preference);

  void toggleDietaryRestriction(String restriction) {
    final next = {...state.dietaryRestrictions};
    next.contains(restriction) ? next.remove(restriction) : next.add(restriction);
    state = state.copyWith(dietaryRestrictions: next);
  }

  void updateBaseline({int? pushUps, int? squats, int? pullUps, int? plankSeconds}) {
    state = state.copyWith(
      baselinePushUps: pushUps,
      baselineSquats: squats,
      baselinePullUps: pullUps,
      baselinePlankSeconds: plankSeconds,
    );
  }

  /// Persists the profile, generates the first week of workouts from it,
  /// and returns the new local profile id. Throws if the draft is
  /// incomplete — the UI is expected to gate the "Finish" button on
  /// [OnboardingDraft.isReadyToSubmit] so this should never fire on bad
  /// input in practice, but it's a real assertion, not decoration.
  Future<String> submit() async {
    if (!state.isReadyToSubmit) {
      throw StateError('Cannot submit onboarding: required fields are missing.');
    }

    final profileRepository = ref.read(profileRepositoryProvider);
    final profileId = await profileRepository.completeOnboarding(state);

    final workoutPlanRepository = ref.read(workoutPlanRepositoryProvider);
    await workoutPlanRepository.generateAndPersistFirstWeek(
      userId: profileId,
      trainingProfile: TrainingProfile(
        fitnessLevel: fitnessLevelFromString(state.fitnessLevel),
        availableEquipment: state.equipment,
        daysPerWeek: state.availabilityDaysPerWeek,
        minutesPerSession: state.availabilityMinutesPerSession,
        goals: state.goals,
      ),
      startDate: DateTime.now(),
    );

    return profileId;
  }
}
