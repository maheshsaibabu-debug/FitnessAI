import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../domain/fitness_engine/fitness_assessment_engine.dart';
import '../../domain/nutrition_engine/nutrition_calculation_engine.dart';
import '../../features/onboarding/domain/onboarding_draft.dart';

const _uuid = Uuid();

/// Persists a completed onboarding draft as the local profile, primary
/// goal, baseline assessment, starting weight entry, and computed
/// nutrition targets — all in one transaction, so a crash mid-write can
/// never leave a half-created profile behind.
///
/// Deliberately does not enqueue a sync-outbox entry yet: every synced
/// table's `user_id` must equal a real Supabase `auth.uid()`, and this
/// phase doesn't implement auth. Writing a sync entry against an id that
/// will never match a real auth user would be sync activity that can only
/// ever fail — enqueuing starts once the auth phase gives these rows a
/// real owner to sync to.
class ProfileRepository {
  ProfileRepository(this._db);

  final AppDatabase _db;

  Stream<UserProfile?> watchActiveProfile() {
    return (_db.select(_db.userProfiles)..limit(1)).watchSingleOrNull();
  }

  Future<UserProfile?> activeProfileOnce() {
    return (_db.select(_db.userProfiles)..limit(1)).getSingleOrNull();
  }

  Future<String> completeOnboarding(OnboardingDraft draft) async {
    assert(draft.isReadyToSubmit, 'completeOnboarding called with an incomplete draft');

    final now = DateTime.now().toUtc();
    final profileId = _uuid.v4();

    final assessment = draft.hasBaselineData
        ? const FitnessAssessmentEngine().assess(
            sex: _toAssessmentSex(draft.sex),
            baseline: BaselineInput(
              pushUpsReps: draft.baselinePushUps,
              squatsReps: draft.baselineSquats,
              pullUpsReps: draft.baselinePullUps,
              plankSeconds: draft.baselinePlankSeconds,
            ),
          )
        : null;

    // The baseline test, when taken, is authoritative over the
    // self-reported level from the earlier step — a measured result beats
    // a guess.
    final resolvedFitnessLevel = assessment != null ? _levelName(assessment.overallLevel) : draft.fitnessLevel!;

    final ageYears = _ageInYears(draft.dateOfBirth!, now);
    final activityLevel =
        const NutritionCalculationEngine().inferActivityLevel(trainingDaysPerWeek: draft.availabilityDaysPerWeek);
    final nutritionTargets = const NutritionCalculationEngine().calculateTargets(
      sex: _toBiologicalSex(draft.sex),
      weightKg: draft.weightKg!,
      heightCm: draft.heightCm!,
      ageYears: ageYears,
      activityLevel: activityLevel,
      goal: _toNutritionGoalType(draft.primaryGoal),
    );

    await _db.transaction(() async {
      await _db.into(_db.userProfiles).insert(UserProfilesCompanion.insert(
            id: profileId,
            name: draft.name.trim(),
            sex: draft.sex!,
            dateOfBirth: Value(draft.dateOfBirth),
            heightCm: Value(draft.heightCm),
            trainingLocation: Value(draft.trainingLocation),
            equipmentJson: Value(_jsonList(draft.equipment)),
            fitnessLevel: Value(resolvedFitnessLevel),
            availabilityDaysPerWeek: Value(draft.availabilityDaysPerWeek),
            availabilityMinutesPerSession: Value(draft.availabilityMinutesPerSession),
            preferredTimeOfDay: Value(draft.preferredTimeOfDay),
            dietaryPreference: Value(draft.dietaryPreference),
            dietaryRestrictionsJson: Value(_jsonList(draft.dietaryRestrictions)),
            onboardingCompleted: const Value(true),
            createdAt: now,
            updatedAt: now,
          ));

      // One row per selected goal — the first one picked (see
      // OnboardingDraft.goals doc comment) is flagged primary.
      for (final goal in draft.goals) {
        await _db.into(_db.fitnessGoals).insert(FitnessGoalsCompanion.insert(
              id: _uuid.v4(),
              userId: profileId,
              goalType: goal,
              isPrimary: Value(goal == draft.primaryGoal),
              createdAt: now,
              updatedAt: now,
            ));
      }

      if (draft.hasBaselineData) {
        await _db.into(_db.fitnessBaselines).insert(FitnessBaselinesCompanion.insert(
              id: _uuid.v4(),
              userId: profileId,
              baselineDate: now,
              pushUpsReps: Value(draft.baselinePushUps),
              squatsReps: Value(draft.baselineSquats),
              pullUpsReps: Value(draft.baselinePullUps),
              plankSeconds: Value(draft.baselinePlankSeconds),
              createdAt: now,
            ));
      }

      await _db.into(_db.weightLogs).insert(WeightLogsCompanion.insert(
            id: _uuid.v4(),
            userId: profileId,
            weightKg: draft.weightKg!,
            recordedAt: now,
            eventId: _uuid.v4(),
            createdAt: now,
          ));

      await _db.into(_db.nutritionGoals).insert(NutritionGoalsCompanion.insert(
            id: _uuid.v4(),
            userId: profileId,
            calorieTarget: nutritionTargets.calorieTarget,
            proteinGrams: nutritionTargets.proteinGrams,
            carbsGrams: nutritionTargets.carbsGrams,
            fatGrams: nutritionTargets.fatGrams,
            calculationMethod: nutritionTargets.calculationMethod,
            updatedAt: now,
          ));
    });

    return profileId;
  }

  String _jsonList(Set<String> values) => '[${values.map((v) => '"$v"').join(',')}]';

  int _ageInYears(DateTime dob, DateTime now) {
    var age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) age--;
    return age;
  }

  String _levelName(FitnessLevel level) => switch (level) {
        FitnessLevel.beginner => 'beginner',
        FitnessLevel.intermediate => 'intermediate',
        FitnessLevel.advanced => 'advanced',
      };
}

AssessmentSex _toAssessmentSex(String? sex) => switch (sex) {
      'male' => AssessmentSex.male,
      'female' => AssessmentSex.female,
      _ => AssessmentSex.other,
    };

BiologicalSex _toBiologicalSex(String? sex) => switch (sex) {
      'male' => BiologicalSex.male,
      'female' => BiologicalSex.female,
      _ => BiologicalSex.other,
    };

NutritionGoalType _toNutritionGoalType(String? goal) => switch (goal) {
      'fat_loss' => NutritionGoalType.fatLoss,
      'muscle_gain' => NutritionGoalType.muscleGain,
      'weight_gain' => NutritionGoalType.weightGain,
      _ => NutritionGoalType.maintain,
    };
