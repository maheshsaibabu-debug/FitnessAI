import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../domain/fitness_engine/fitness_assessment_engine.dart';
import '../../domain/nutrition_engine/nutrition_calculation_engine.dart';
import '../../domain/workout_engine/workout_generation_engine.dart';
import '../../features/onboarding/domain/onboarding_draft.dart';
import 'workout_plan_repository.dart' show fitnessLevelFromString;

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

  Stream<Set<String>> watchGoals(String userId) {
    return (_db.select(_db.fitnessGoals)..where((g) => g.userId.equals(userId)))
        .watch()
        .map((rows) => rows.map((r) => r.goalType).toSet());
  }

  /// One-shot equivalent of [watchGoals] — for a caller that just needs
  /// the current value once (e.g. FitnessContextResolver) rather than a
  /// live subscription, this avoids `.watch().first`'s stream-teardown
  /// cost (and, under flutter_test's FakeAsync zone with no `pump()`
  /// calls, its zero-duration-Timer-that-never-fires hang risk).
  Future<Set<String>> goalsOnce(String userId) async {
    final rows = await (_db.select(_db.fitnessGoals)..where((g) => g.userId.equals(userId))).get();
    return rows.map((r) => r.goalType).toSet();
  }

  /// The single goal flagged primary at onboarding (see
  /// OnboardingDraft.goals) — used to recompute nutrition targets on a
  /// plan regenerate without asking the user to redo onboarding.
  Future<String?> primaryGoalOnce(String userId) async {
    final row = await primaryGoalRowOnce(userId);
    return row?.goalType;
  }

  /// Full primary-goal row, including `targetValue`/`targetDate` — these
  /// two columns existed in the schema from the start but were unused
  /// until the Program view needed a real goal-weight-by-date to build a
  /// trajectory from (ai/program/program_trajectory_engine.dart).
  Future<FitnessGoal?> primaryGoalRowOnce(String userId) {
    return (_db.select(_db.fitnessGoals)
          ..where((g) => g.userId.equals(userId) & g.isPrimary.equals(true))
          ..limit(1))
        .getSingleOrNull();
  }

  /// Sets the target weight/date on the user's primary goal — the input
  /// the Program view's trajectory is computed from. Overwrites any
  /// previous target, matching "edit your goal" rather than "add another
  /// goal."
  Future<void> setGoalTarget(String userId, {required double targetWeightKg, required DateTime targetDate}) async {
    final primary = await primaryGoalRowOnce(userId);
    if (primary == null) return;
    await (_db.update(_db.fitnessGoals)..where((g) => g.id.equals(primary.id))).write(
      FitnessGoalsCompanion(
        targetValue: Value(targetWeightKg),
        targetDate: Value(targetDate),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// Reassembles the engine's [TrainingProfile] input from what's already
  /// on disk — used to regenerate a plan against the same profile the
  /// user onboarded with, without asking them to redo onboarding.
  Future<TrainingProfile?> currentTrainingProfile() async {
    final profile = await activeProfileOnce();
    if (profile == null) return null;

    final goalRows = await (_db.select(_db.fitnessGoals)..where((g) => g.userId.equals(profile.id))).get();

    return TrainingProfile(
      fitnessLevel: fitnessLevelFromString(profile.fitnessLevel),
      availableEquipment: _parseJsonList(profile.equipmentJson),
      daysPerWeek: profile.availabilityDaysPerWeek ?? 3,
      minutesPerSession: profile.availabilityMinutesPerSession ?? 30,
      goals: goalRows.map((g) => g.goalType).toSet(),
    );
  }

  Future<NutritionGoal?> nutritionTargetsOnce(String userId) {
    return (_db.select(_db.nutritionGoals)..where((g) => g.userId.equals(userId))).getSingleOrNull();
  }

  /// Replaces the user's stored nutrition targets — used by the Plan
  /// screen's regenerate action so a refreshed AI/deterministic plan
  /// updates diet targets too, not just the workout days. Re-applies the
  /// safety floor regardless of source, same as [completeOnboarding].
  Future<void> updateNutritionTargets(String userId, NutritionTargets nutritionTargets) async {
    final now = DateTime.now().toUtc();
    final safeCalorieTarget = nutritionTargets.calorieTarget < NutritionCalculationEngine.minSafeCalories
        ? NutritionCalculationEngine.minSafeCalories
        : nutritionTargets.calorieTarget;
    final existing = await (_db.select(_db.nutritionGoals)..where((g) => g.userId.equals(userId))).getSingleOrNull();

    final companion = NutritionGoalsCompanion(
      calorieTarget: Value(safeCalorieTarget),
      proteinGrams: Value(nutritionTargets.proteinGrams < 0 ? 0 : nutritionTargets.proteinGrams),
      carbsGrams: Value(nutritionTargets.carbsGrams < 0 ? 0 : nutritionTargets.carbsGrams),
      fatGrams: Value(nutritionTargets.fatGrams < 0 ? 0 : nutritionTargets.fatGrams),
      calculationMethod: Value(nutritionTargets.calculationMethod),
      updatedAt: Value(now),
    );

    if (existing == null) {
      await _db.into(_db.nutritionGoals).insert(NutritionGoalsCompanion.insert(
            id: _uuid.v4(),
            userId: userId,
            calorieTarget: companion.calorieTarget.value,
            proteinGrams: companion.proteinGrams.value,
            carbsGrams: companion.carbsGrams.value,
            fatGrams: companion.fatGrams.value,
            calculationMethod: companion.calculationMethod.value,
            updatedAt: now,
          ));
    } else {
      await (_db.update(_db.nutritionGoals)..where((g) => g.id.equals(existing.id))).write(companion);
    }
  }

  Set<String> _parseJsonList(String json) {
    if (json.isEmpty) return {};
    return (jsonDecode(json) as List).map((v) => v.toString()).toSet();
  }

  /// [nutritionTargets] is required rather than computed here — the
  /// caller (OnboardingController) decides whether it comes from the AI
  /// plan path or the deterministic [NutritionCalculationEngine] fallback
  /// (see ai/plan/plan_generation_service.dart), but either way the
  /// safety floor gets re-applied here too, one more time, regardless of
  /// source — see product spec §25.
  Future<String> completeOnboarding(OnboardingDraft draft, {required NutritionTargets nutritionTargets}) async {
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
    final safeCalorieTarget = nutritionTargets.calorieTarget < NutritionCalculationEngine.minSafeCalories
        ? NutritionCalculationEngine.minSafeCalories
        : nutritionTargets.calorieTarget;

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
            calorieTarget: safeCalorieTarget,
            proteinGrams: nutritionTargets.proteinGrams < 0 ? 0 : nutritionTargets.proteinGrams,
            carbsGrams: nutritionTargets.carbsGrams < 0 ? 0 : nutritionTargets.carbsGrams,
            fatGrams: nutritionTargets.fatGrams < 0 ? 0 : nutritionTargets.fatGrams,
            calculationMethod: nutritionTargets.calculationMethod,
            updatedAt: now,
          ));
    });

    return profileId;
  }

  String _jsonList(Set<String> values) => '[${values.map((v) => '"$v"').join(',')}]';

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

int _ageInYearsFrom(DateTime dob, DateTime now) {
  var age = now.year - dob.year;
  if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) age--;
  return age;
}

/// [NutritionCalculationEngine.calculateTargetsFor]'s input, assembled
/// from an onboarding draft — shared by the deterministic fallback and
/// the AI plan path (ai/plan/plan_generation_service.dart) so both send
/// identical framing regardless of which one runs.
NutritionRequestInput nutritionRequestInputFor(OnboardingDraft draft) {
  return NutritionRequestInput(
    sex: _toBiologicalSex(draft.sex),
    weightKg: draft.weightKg!,
    heightCm: draft.heightCm!,
    ageYears: _ageInYearsFrom(draft.dateOfBirth!, DateTime.now().toUtc()),
    activityLevel:
        const NutritionCalculationEngine().inferActivityLevel(trainingDaysPerWeek: draft.availabilityDaysPerWeek),
    goal: _toNutritionGoalType(draft.primaryGoal),
  );
}

/// [nutritionRequestInputFor]'s counterpart for an already-onboarded
/// profile — used by the Plan screen's regenerate action, which has a
/// saved [UserProfile] rather than a live [OnboardingDraft]. Weight and
/// primary goal aren't columns on UserProfile (weight is a time-series
/// log, goals are their own table), so the caller supplies them.
NutritionRequestInput nutritionRequestInputForProfile(
  UserProfile profile, {
  required double weightKg,
  required String? primaryGoal,
}) {
  return NutritionRequestInput(
    sex: _toBiologicalSex(profile.sex),
    weightKg: weightKg,
    heightCm: profile.heightCm ?? 170,
    ageYears: profile.dateOfBirth == null ? 30 : _ageInYearsFrom(profile.dateOfBirth!, DateTime.now().toUtc()),
    activityLevel: const NutritionCalculationEngine()
        .inferActivityLevel(trainingDaysPerWeek: profile.availabilityDaysPerWeek ?? 3),
    goal: _toNutritionGoalType(primaryGoal),
  );
}
