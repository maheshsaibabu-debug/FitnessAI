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

      var order = 0;
      final exercises = <GeneratedExercise>[];
      for (final rawExercise in rawExercises) {
        final exercise = _parseExercise(rawExercise, libraryById, usableEquipment, levelRank, order);
        if (exercise == null) continue;
        exercises.add(exercise);
        order++;
      }
      if (exercises.isEmpty) continue; // whole day was junk -> the day-count check below catches this

      final workoutType = (rawWorkout['workoutType'] as String?) ?? 'strength_full_body';
      final title = (rawWorkout['title'] as String?) ?? 'Workout';
      workouts.add(GeneratedWorkout(
        dayOffset: dayOffset,
        workoutType: workoutType,
        title: title,
        estimatedMinutes: estimatedMinutesFor(exercises),
        exercises: exercises,
      ));
    }
    return workouts;
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
