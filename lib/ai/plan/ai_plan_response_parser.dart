import '../../domain/fitness_engine/fitness_assessment_engine.dart';
import '../../domain/nutrition_engine/nutrition_calculation_engine.dart';
import '../../domain/workout_engine/exercise_summary.dart';
import '../../domain/workout_engine/workout_generation_engine.dart';
import '../ai_provider.dart' show AiProviderException;

class AiGeneratedPlan {
  const AiGeneratedPlan({required this.plan, required this.nutrition, this.model});
  final GeneratedPlan plan;
  final NutritionTargets nutrition;
  final String? model;
}

/// Turns the AI plan gateway's (untrusted) JSON into the same
/// [GeneratedPlan]/[NutritionTargets] types the deterministic engines
/// produce. Pure and network-free by design — [AiPlanProvider] does the
/// HTTP call and hands the raw decoded body here — so every validation
/// rule is unit-testable without a Supabase client.
///
/// Nothing the model returns is trusted as-is: every exercise id is
/// checked against the real library, every equipment/level constraint is
/// re-enforced here (not just asked for in the prompt — see
/// docs/AI_ARCHITECTURE.md's "never delegated to the LLM"), and the
/// nutrition safety floor is re-applied regardless of what the model
/// proposed. A response that doesn't hold up throws
/// [AiProviderException], which the caller (PlanGenerationService) turns
/// into a fallback to the fully deterministic engines — this class can
/// degrade the plan's personalization, it can never corrupt it.
class AiPlanResponseParser {
  const AiPlanResponseParser();

  AiGeneratedPlan parse({
    required Map<dynamic, dynamic> rawPlan,
    required String? model,
    required TrainingProfile trainingProfile,
    required List<ExerciseSummary> library,
    required NutritionRequestInput nutritionInput,
  }) {
    final workouts = _parseWorkouts(rawPlan['workouts'], trainingProfile, library);
    if (workouts.length < trainingProfile.daysPerWeek) {
      throw AiProviderException(
        'Plan generator produced an incomplete plan (${workouts.length}/${trainingProfile.daysPerWeek} valid days)',
      );
    }
    workouts.sort((a, b) => a.dayOffset.compareTo(b.dayOffset));

    final nutrition = _parseNutrition(rawPlan['nutrition'], nutritionInput);

    return AiGeneratedPlan(plan: GeneratedPlan(workouts: workouts), nutrition: nutrition, model: model);
  }

  List<GeneratedWorkout> _parseWorkouts(
    dynamic rawWorkouts,
    TrainingProfile trainingProfile,
    List<ExerciseSummary> library,
  ) {
    if (rawWorkouts is! List) throw AiProviderException('Plan generator response missing workouts');

    final libraryById = {for (final e in library) e.id: e};
    final usableEquipment = {...trainingProfile.availableEquipment, 'none'};
    final levelRank = _levelRank(_levelName(trainingProfile.fitnessLevel));
    final seenDays = <int>{};

    final workouts = <GeneratedWorkout>[];
    for (final rawWorkout in rawWorkouts) {
      if (rawWorkout is! Map) continue;
      final dayOffset = rawWorkout['dayOffset'];
      if (dayOffset is! int || dayOffset < 0 || dayOffset >= trainingProfile.daysPerWeek) continue;
      if (!seenDays.add(dayOffset)) continue; // duplicate day -> keep the first

      final rawExercises = rawWorkout['exercises'];
      if (rawExercises is! List) continue;

      final workoutType = (rawWorkout['workoutType'] as String?) ?? 'strength_full_body';
      final title = (rawWorkout['title'] as String?) ?? 'Workout';

      var order = 0;
      final exercises = <GeneratedExercise>[];
      final usedInDay = <String>{};
      for (final rawExercise in rawExercises) {
        final exercise = _parseExercise(rawExercise, libraryById, usableEquipment, levelRank, order);
        if (exercise == null) continue;
        if (!usedInDay.add(exercise.exerciseId)) continue; // the model repeated an exercise within the day
        exercises.add(exercise);
        order++;
      }
      if (exercises.isEmpty) continue; // whole day was junk -> the day-count check below catches this

      // The model doesn't always fill a day out to the requested session
      // length on its own (a "60-minute" gym day can come back with only
      // 4-5 exercises) — top it back up with more real, valid exercises
      // from the same muscle-group patterns already present, the same
      // way WorkoutGenerationEngine fills a deterministic day.
      final toppedUp = _topUpToTarget(
        exercises: exercises,
        usedIds: usedInDay,
        libraryById: libraryById,
        library: library,
        usableEquipment: usableEquipment,
        levelRank: levelRank,
        targetSeconds: trainingProfile.minutesPerSession * 60,
        workoutType: workoutType,
      );

      workouts.add(GeneratedWorkout(
        dayOffset: dayOffset,
        workoutType: workoutType,
        title: title,
        estimatedMinutes: estimatedMinutesFor(toppedUp),
        exercises: toppedUp,
      ));
    }
    return workouts;
  }

  /// Fills a day back out toward [targetSeconds] using more real
  /// exercises from the same movement patterns the model already picked
  /// for that day (e.g. a chest/triceps day only tops up with more
  /// push-pattern exercises) — reusing the day's own sets/reps/rest
  /// scheme for consistency. Skipped for hiit/cardio days, which the
  /// model already owns the full structure of, and if the day already
  /// meets or exceeds the target.
  List<GeneratedExercise> _topUpToTarget({
    required List<GeneratedExercise> exercises,
    required Set<String> usedIds,
    required Map<String, ExerciseSummary> libraryById,
    required List<ExerciseSummary> library,
    required Set<String> usableEquipment,
    required int levelRank,
    required int targetSeconds,
    required String workoutType,
  }) {
    if (workoutType == 'hiit' || workoutType == 'cardio') return exercises;
    if (workoutSecondsFor(exercises) >= targetSeconds) return exercises;

    final patterns = exercises
        .map((e) => libraryById[e.exerciseId])
        .whereType<ExerciseSummary>()
        .map(movementPatternFor)
        .toSet()
        .toList();
    if (patterns.isEmpty) return exercises;

    final result = List<GeneratedExercise>.from(exercises);
    final reference = result.first;
    var order = result.length;

    var addedThisRound = true;
    while (workoutSecondsFor(result) < targetSeconds && addedThisRound) {
      addedThisRound = false;
      for (final pattern in patterns) {
        if (workoutSecondsFor(result) >= targetSeconds) break;

        final candidates = library.where((e) {
          if (usedIds.contains(e.id)) return false;
          if (movementPatternFor(e) != pattern) return false;
          if (!exerciseUsesAvailableEquipment(e.equipment, usableEquipment)) return false;
          return levelRankFor(e.difficulty) <= levelRank;
        }).toList()
          ..sort((a, b) => a.id.compareTo(b.id));

        if (candidates.isEmpty) continue;
        final chosen = candidates.first;
        usedIds.add(chosen.id);
        result.add(GeneratedExercise(
          exerciseId: chosen.id,
          orderIndex: order++,
          targetSets: reference.targetSets,
          targetReps: reference.targetReps,
          targetDurationSeconds: reference.targetDurationSeconds,
          restSeconds: reference.restSeconds,
        ));
        addedThisRound = true;
      }
    }

    return result;
  }

  GeneratedExercise? _parseExercise(
    dynamic rawExercise,
    Map<String, ExerciseSummary> libraryById,
    Set<String> usableEquipment,
    int levelRank,
    int orderIndex,
  ) {
    if (rawExercise is! Map) return null;
    final exerciseId = rawExercise['exerciseId'];
    if (exerciseId is! String) return null;

    final exercise = libraryById[exerciseId];
    if (exercise == null) return null; // hallucinated id
    if (!exerciseUsesAvailableEquipment(exercise.equipment, usableEquipment)) return null; // equipment the user doesn't have
    if (_levelRank(exercise.difficulty) > levelRank) return null; // too advanced

    final targetSets = (rawExercise['targetSets'] as num?)?.toInt();
    final targetReps = (rawExercise['targetReps'] as num?)?.toInt();
    final targetDurationSeconds = (rawExercise['targetDurationSeconds'] as num?)?.toInt();
    final restSeconds = (rawExercise['restSeconds'] as num?)?.toInt();
    if (targetSets == null || targetSets <= 0) return null;
    if (restSeconds == null || restSeconds < 0) return null;
    // Exactly one of reps/duration, matching GeneratedExercise's contract.
    if ((targetReps == null) == (targetDurationSeconds == null)) return null;

    return GeneratedExercise(
      exerciseId: exerciseId,
      orderIndex: orderIndex,
      targetSets: targetSets,
      targetReps: targetReps,
      targetDurationSeconds: targetDurationSeconds,
      restSeconds: restSeconds,
    );
  }

  NutritionTargets _parseNutrition(dynamic raw, NutritionRequestInput input) {
    if (raw is! Map) throw AiProviderException('Plan generator response missing nutrition');

    final rawCalorieTarget = (raw['calorieTarget'] as num?)?.toInt();
    final rawProteinGrams = (raw['proteinGrams'] as num?)?.toDouble();
    final rawCarbsGrams = (raw['carbsGrams'] as num?)?.toDouble();
    final rawFatGrams = (raw['fatGrams'] as num?)?.toDouble();
    if (rawCalorieTarget == null || rawProteinGrams == null || rawCarbsGrams == null || rawFatGrams == null) {
      throw AiProviderException('Plan generator returned incomplete nutrition numbers');
    }

    // Non-negotiable safety floor regardless of source — see
    // NutritionCalculationEngine.minSafeCalories and product spec §25.
    final calorieTarget = rawCalorieTarget < NutritionCalculationEngine.minSafeCalories
        ? NutritionCalculationEngine.minSafeCalories
        : rawCalorieTarget;
    final proteinGrams = rawProteinGrams < 0 ? 0.0 : rawProteinGrams;
    final carbsGrams = rawCarbsGrams < 0 ? 0.0 : rawCarbsGrams;
    final fatGrams = rawFatGrams < 0 ? 0.0 : rawFatGrams;

    // BMR/TDEE have no AI equivalent — compute them deterministically so
    // the stored record stays meaningful rather than faking them.
    const engine = NutritionCalculationEngine();
    final bmr =
        engine.calculateBmr(sex: input.sex, weightKg: input.weightKg, heightCm: input.heightCm, ageYears: input.ageYears);
    final tdee = engine.calculateTdee(bmr: bmr, activityLevel: input.activityLevel);

    return NutritionTargets(
      bmr: bmr,
      tdee: tdee,
      calorieTarget: calorieTarget,
      proteinGrams: proteinGrams,
      carbsGrams: carbsGrams,
      fatGrams: fatGrams,
      calculationMethod: 'ai_generated',
    );
  }

  String _levelName(FitnessLevel level) => switch (level) {
        FitnessLevel.beginner => 'beginner',
        FitnessLevel.intermediate => 'intermediate',
        FitnessLevel.advanced => 'advanced',
      };

  int _levelRank(String difficulty) => switch (difficulty) {
        'beginner' => 0,
        'intermediate' => 1,
        'advanced' => 2,
        _ => 0,
      };
}
