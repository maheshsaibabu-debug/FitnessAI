import '../../domain/nutrition_engine/nutrition_calculation_engine.dart';
import '../../domain/workout_engine/exercise_summary.dart';
import '../../domain/workout_engine/workout_generation_engine.dart';
import '../ai_provider.dart' show AiProviderException;
import 'ai_plan_provider.dart';

class PlanGenerationResult {
  const PlanGenerationResult({required this.plan, required this.nutrition, required this.source, this.model});

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
class PlanGenerationService {
  PlanGenerationService({required this.aiPlanProvider});

  final AiPlanProvider aiPlanProvider;

  Future<PlanGenerationResult> generate({
    required TrainingProfile trainingProfile,
    required List<ExerciseSummary> library,
    required NutritionRequestInput nutritionInput,
  }) async {
    try {
      final aiResult = await aiPlanProvider.generate(
        trainingProfile: trainingProfile,
        library: library,
        nutritionInput: nutritionInput,
      );
      return PlanGenerationResult(plan: aiResult.plan, nutrition: aiResult.nutrition, source: 'ai', model: aiResult.model);
    } on AiProviderException {
      final plan = const WorkoutGenerationEngine().generateWeek(profile: trainingProfile, exerciseLibrary: library);
      final nutrition = const NutritionCalculationEngine().calculateTargetsFor(nutritionInput);
      return PlanGenerationResult(plan: plan, nutrition: nutrition, source: 'deterministic');
    }
  }
}
