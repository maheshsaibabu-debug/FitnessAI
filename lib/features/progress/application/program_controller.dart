import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../ai/ai_providers.dart';
import '../../../ai/program/program_overview_input.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../domain/nutrition_engine/nutrition_calculation_engine.dart';
import '../../../domain/program_engine/program_trajectory_engine.dart';

part 'program_controller.g.dart';

class ProgramState {
  const ProgramState({
    this.goalWeightKg,
    this.targetDate,
    this.currentWeightKg,
    this.trajectory,
    this.overview,
    this.isGenerating = false,
    this.error,
  });

  final double? goalWeightKg;
  final DateTime? targetDate;
  final double? currentWeightKg;
  final ProgramTrajectory? trajectory;
  final ProgramOverviewResult? overview;
  final bool isGenerating;
  final String? error;

  bool get hasGoal => goalWeightKg != null && targetDate != null;

  ProgramState copyWith({
    double? goalWeightKg,
    DateTime? targetDate,
    double? currentWeightKg,
    ProgramTrajectory? trajectory,
    ProgramOverviewResult? overview,
    bool? isGenerating,
    String? error,
  }) {
    return ProgramState(
      goalWeightKg: goalWeightKg ?? this.goalWeightKg,
      targetDate: targetDate ?? this.targetDate,
      currentWeightKg: currentWeightKg ?? this.currentWeightKg,
      trajectory: trajectory ?? this.trajectory,
      overview: overview ?? this.overview,
      isGenerating: isGenerating ?? this.isGenerating,
      error: error,
    );
  }
}

/// Drives the Program view: reads/sets the goal weight+date already
/// sitting unused on the primary [FitnessGoal] row, computes a real
/// [ProgramTrajectory] from it (never from the LLM — see
/// docs/AI_ARCHITECTURE.md), and generates the narrative overview
/// (AI-first, deterministic-fallback) over that real trajectory plus the
/// user's actual current weekly plan and nutrition targets.
@Riverpod(keepAlive: true)
class ProgramController extends _$ProgramController {
  @override
  Future<ProgramState> build() async {
    final profileRepository = ref.watch(profileRepositoryProvider);
    final profile = await profileRepository.activeProfileOnce();
    if (profile == null) return const ProgramState();

    final goalRow = await profileRepository.primaryGoalRowOnce(profile.id);
    final latestWeight = await ref.watch(weightRepositoryProvider).latestOnce(profile.id);

    return ProgramState(
      goalWeightKg: goalRow?.targetValue,
      targetDate: goalRow?.targetDate,
      currentWeightKg: latestWeight?.weightKg,
    );
  }

  Future<void> setGoal({required double goalWeightKg, required DateTime targetDate}) async {
    final profileRepository = ref.read(profileRepositoryProvider);
    final profile = await profileRepository.activeProfileOnce();
    if (profile == null) return;

    await profileRepository.setGoalTarget(profile.id, targetWeightKg: goalWeightKg, targetDate: targetDate);

    final current = state.valueOrNull ?? const ProgramState();
    state = AsyncData(current.copyWith(goalWeightKg: goalWeightKg, targetDate: targetDate));
    await generateOverview();
  }

  Future<void> generateOverview() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasGoal) return;
    if (current.currentWeightKg == null) {
      state = AsyncData(current.copyWith(error: 'Log a weight entry on the Track tab first.'));
      return;
    }

    state = AsyncData(current.copyWith(isGenerating: true, error: ''));

    try {
      final profileRepository = ref.read(profileRepositoryProvider);
      final profile = await profileRepository.activeProfileOnce();
      if (profile == null) return;

      final trajectory = const ProgramTrajectoryEngine().compute(ProgramTrajectoryInput(
        currentWeightKg: current.currentWeightKg!,
        goalWeightKg: current.goalWeightKg!,
        requestedTargetDate: current.targetDate!,
        today: DateTime.now(),
      ));

      final nutritionRow = await profileRepository.nutritionTargetsOnce(profile.id);
      final nutrition = NutritionTargets(
        bmr: 0,
        tdee: 0,
        calorieTarget: nutritionRow?.calorieTarget ?? NutritionCalculationEngine.minSafeCalories,
        proteinGrams: nutritionRow?.proteinGrams ?? 0,
        carbsGrams: nutritionRow?.carbsGrams ?? 0,
        fatGrams: nutritionRow?.fatGrams ?? 0,
        calculationMethod: nutritionRow?.calculationMethod ?? 'unknown',
      );

      final goals = await profileRepository.goalsOnce(profile.id);

      final workoutPlanRepository = ref.read(workoutPlanRepositoryProvider);
      final workoutExecutionRepository = ref.read(workoutExecutionRepositoryProvider);
      final upcomingWorkouts =
          await workoutPlanRepository.upcomingWorkoutsOnce(profile.id, from: DateTime.now(), limit: 7);

      final weeklyPlan = <ProgramPlanDay>[];
      for (final workout in upcomingWorkouts) {
        final exercises = await workoutExecutionRepository.loadExercises(workout.id);
        weeklyPlan.add(ProgramPlanDay(
          title: workout.title,
          workoutType: workout.workoutType,
          exerciseNames: exercises.map((e) => e.exercise.name).toList(),
        ));
      }

      final overview = await ref.read(programOverviewServiceProvider).generate(ProgramOverviewInput(
            name: profile.name,
            fitnessLevel: profile.fitnessLevel ?? 'beginner',
            goals: goals,
            trajectory: trajectory,
            nutrition: nutrition,
            weeklyPlan: weeklyPlan,
            dietaryPreference: profile.dietaryPreference,
            dietaryRestrictions: _parseJsonStringList(profile.dietaryRestrictionsJson),
          ));

      state = AsyncData(current.copyWith(trajectory: trajectory, overview: overview, isGenerating: false, error: ''));
    } catch (e) {
      state = AsyncData(current.copyWith(isGenerating: false, error: 'Could not generate your program overview: $e'));
    }
  }

  Set<String> _parseJsonStringList(String json) {
    if (json.isEmpty) return {};
    return (jsonDecode(json) as List).map((v) => v.toString()).toSet();
  }
}
