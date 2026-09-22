import '../../domain/nutrition_engine/nutrition_calculation_engine.dart';
import '../../domain/program_engine/program_trajectory_engine.dart';

/// One real, already-scheduled workout day — the plan-of-record, not
/// something the overview generator gets to invent.
class ProgramPlanDay {
  const ProgramPlanDay({required this.title, required this.workoutType, required this.exerciseNames});
  final String title;
  final String workoutType;
  final List<String> exerciseNames;
}

/// Everything the program overview (AI or deterministic) is built from
/// — all of it real, already-computed data: a [ProgramTrajectory] from
/// [ProgramTrajectoryEngine], real [NutritionTargets], and the user's
/// actual current weekly plan.
class ProgramOverviewInput {
  const ProgramOverviewInput({
    required this.name,
    required this.fitnessLevel,
    required this.goals,
    required this.trajectory,
    required this.nutrition,
    required this.weeklyPlan,
    this.dietaryPreference,
    this.dietaryRestrictions = const {},
  });

  final String name;
  final String fitnessLevel;
  final Set<String> goals;
  final ProgramTrajectory trajectory;
  final NutritionTargets nutrition;
  final List<ProgramPlanDay> weeklyPlan;

  /// From onboarding (vegetarian/vegan/omnivore/pescatarian/other) — lets
  /// the overview suggest real meals instead of generic "eat protein"
  /// advice, without us hard-coding a food/cuisine database.
  final String? dietaryPreference;
  final Set<String> dietaryRestrictions;
}

/// One suggested meal — a label ("Breakfast", "Pre-workout") and real,
/// concrete food suggestion text, not "eat protein."
class MealSuggestion {
  const MealSuggestion({required this.label, required this.suggestion});
  final String label;
  final String suggestion;
}

/// The overview, broken into sections a screen can lay out as separate
/// cards — in particular so nutrition/meal suggestions are their own
/// findable section rather than buried partway through one long block
/// of prose (the original flat-string design; a real usability
/// complaint, not a hypothetical one).
class ProgramOverviewResult {
  const ProgramOverviewResult({
    required this.summary,
    required this.weeklyPlanNarrative,
    required this.nutritionSummary,
    required this.meals,
    required this.trackingChecklist,
    required this.closingLine,
    required this.source,
    this.model,
  });

  final String summary;
  final String weeklyPlanNarrative;
  final String nutritionSummary;
  final List<MealSuggestion> meals;
  final List<String> trackingChecklist;
  final String closingLine;

  /// 'ai' | 'deterministic' — surfaced so the UI can be honest about
  /// which one produced this text, same as everywhere else in this app.
  final String source;
  final String? model;
}
