import 'package:fitness_companion/ai/program/deterministic_program_overview_builder.dart';
import 'package:fitness_companion/ai/program/program_overview_input.dart';
import 'package:fitness_companion/domain/nutrition_engine/nutrition_calculation_engine.dart';
import 'package:fitness_companion/domain/program_engine/program_trajectory_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const builder = DeterministicProgramOverviewBuilder();

  ProgramOverviewInput input({bool adjusted = false}) {
    final trajectory = ProgramTrajectory(
      startWeightKg: 85,
      goalWeightKg: 70,
      requestedTargetDate: DateTime(2026, 7, 1),
      effectiveTargetDate: DateTime(2026, 7, 1),
      wasAdjusted: adjusted,
      adjustmentReason: adjusted ? 'Your requested pace was too fast, so the timeline was extended.' : null,
      weeklyRateKg: -0.58,
      milestones: [
        ProgramMilestone(date: DateTime(2026, 1, 1), weightKg: 85, label: 'Start'),
        ProgramMilestone(date: DateTime(2026, 7, 1), weightKg: 70, label: 'Goal'),
      ],
    );
    return ProgramOverviewInput(
      name: 'Alex',
      fitnessLevel: 'intermediate',
      goals: const {'fat_loss'},
      trajectory: trajectory,
      nutrition: const NutritionTargets(
        bmr: 1800, tdee: 2500, calorieTarget: 2200, proteinGrams: 170, carbsGrams: 220, fatGrams: 65,
        calculationMethod: 'mifflin_st_jeor',
      ),
      weeklyPlan: const [
        ProgramPlanDay(title: 'Push Day', workoutType: 'push', exerciseNames: ['Push-up', 'Plank']),
      ],
    );
  }

  test('always returns source "deterministic"', () {
    final result = builder.build(input());
    expect(result.source, 'deterministic');
  });

  test('includes every milestone and every real workout day, never inventing extras', () {
    final result = builder.build(input());
    expect(result.overview, contains('85.0 kg'));
    expect(result.overview, contains('70.0 kg'));
    expect(result.overview, contains('Push Day'));
    expect(result.overview, contains('Push-up, Plank'));
  });

  test('surfaces the adjustment reason when the timeline was safety-adjusted', () {
    final result = builder.build(input(adjusted: true));
    expect(result.overview, contains('timeline was extended'));
  });

  test('omits adjustment language when nothing was adjusted', () {
    final result = builder.build(input());
    expect(result.overview, isNot(contains('timeline was extended')));
  });

  test('states the real nutrition numbers, not placeholders', () {
    final result = builder.build(input());
    expect(result.overview, contains('2200 kcal/day'));
    expect(result.overview, contains('170g protein'));
  });
}
