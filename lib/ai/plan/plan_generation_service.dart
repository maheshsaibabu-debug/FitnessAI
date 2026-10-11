import '../../domain/nutrition_engine/nutrition_calculation_engine.dart';
import '../../domain/workout_engine/exercise_summary.dart';
import '../../domain/workout_engine/workout_generation_engine.dart';
import '../ai_provider.dart' show AiProviderException;
import 'ai_plan_provider.dart';

class PlanGenerationResult {
  const PlanGenerationResult({
    required this.plan,
    required this.nutrition,
    required this.source,
    this.model,
  });

  final GeneratedPlan plan;
  final NutritionTargets nutrition;

  /// 'ai' or 'deterministic' — surfaced so the UI can be honest about
  /// which engine actually produced this plan (mirrors the Coach chat's
  /// "Offline reply" labeling).
  final String source;
  final String? model;
}

/// Tries the LLM-driven plan first, falls back to the deterministic
/// engines on any failure (offline, gateway error, a response that
/// didn't survive [AiPlanProvider]'s validation) — the same pattern
/// already used for Coach chat (CloudAiProvider -> RuleBasedFallbackProvider),
/// applied to plan generation itself. This is what keeps onboarding
/// working with zero connectivity, per docs/OFFLINE_FIRST.md, while
/// still using the LLM when it's available.
///
/// Also caches the last AI result in memory, keyed on every plan-relevant
/// input (profile constraints + goals + nutrition input) — this service is
/// `keepAlive`d by its Riverpod provider, so the cache survives across
/// repeat "Regenerate plan" taps for the same inputs, avoiding a paid-model
/// call when nothing has actually changed. A single slot is enough: there's
/// only ever one "current user" worth of inputs alive at a time.
class PlanGenerationService {
  PlanGenerationService({required this.aiPlanProvider});

  final AiPlanProvider aiPlanProvider;

  TrainingProfile? _cachedProfile;
  NutritionRequestInput? _cachedNutritionInput;
  PlanGenerationResult? _cachedResult;

  Future<PlanGenerationResult> generate({
    required TrainingProfile trainingProfile,
    required List<ExerciseSummary> library,
    required NutritionRequestInput nutritionInput,
  }) async {
    final cachedResult = _cachedResult;
    final cachedProfile = _cachedProfile;
    final cachedNutritionInput = _cachedNutritionInput;
    if (cachedResult != null &&
        cachedProfile != null &&
        cachedNutritionInput != null &&
        _sameProfile(cachedProfile, trainingProfile) &&
        _sameNutritionInput(cachedNutritionInput, nutritionInput)) {
      return cachedResult;
    }

    try {
      final aiResult = await aiPlanProvider.generate(
        trainingProfile: trainingProfile,
        library: library,
        nutritionInput: nutritionInput,
      );
      final result = PlanGenerationResult(
        plan: aiResult.plan,
        nutrition: aiResult.nutrition,
        source: 'ai',
        model: aiResult.model,
      );
      _cachedProfile = trainingProfile;
      _cachedNutritionInput = nutritionInput;
      _cachedResult = result;
      return result;
    } on AiProviderException {
      // Never cache a fallback — a transient AI failure shouldn't make the
      // cache skip the real model on every later call with the same inputs.
      _cachedResult = null;
      final plan = const WorkoutGenerationEngine().generateWeek(
        profile: trainingProfile,
        exerciseLibrary: library,
      );
      final nutrition = const NutritionCalculationEngine().calculateTargetsFor(
        nutritionInput,
      );
      return PlanGenerationResult(
        plan: plan,
        nutrition: nutrition,
        source: 'deterministic',
      );
    }
  }

  bool _sameProfile(TrainingProfile a, TrainingProfile b) =>
      a.fitnessLevel == b.fitnessLevel &&
      a.daysPerWeek == b.daysPerWeek &&
      a.minutesPerSession == b.minutesPerSession &&
      _setEquals(a.availableEquipment, b.availableEquipment) &&
      _setEquals(a.goals, b.goals);

  bool _sameNutritionInput(NutritionRequestInput a, NutritionRequestInput b) =>
      a.sex == b.sex &&
      a.weightKg == b.weightKg &&
      a.heightCm == b.heightCm &&
      a.ageYears == b.ageYears &&
      a.activityLevel == b.activityLevel &&
      a.goal == b.goal;

  bool _setEquals(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}
