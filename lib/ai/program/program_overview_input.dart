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
  });

  final String name;
  final String fitnessLevel;
  final Set<String> goals;
  final ProgramTrajectory trajectory;
  final NutritionTargets nutrition;
  final List<ProgramPlanDay> weeklyPlan;
}

class ProgramOverviewResult {
  const ProgramOverviewResult({required this.overview, required this.source, this.model});

  final String overview;

  /// 'ai' | 'deterministic' — surfaced so the UI can be honest about
  /// which one produced this text, same as everywhere else in this app.
  final String source;
  final String? model;
}
