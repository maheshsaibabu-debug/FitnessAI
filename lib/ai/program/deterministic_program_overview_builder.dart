import 'program_overview_input.dart';

/// The offline fallback for the Program view — pure text, no network,
/// built from exactly the same real numbers the AI path would have
/// narrated. Plainer prose, same facts: docs/AI_ARCHITECTURE.md's rule
/// that a failed cloud call must still produce something real and
/// useful, never a bare error.
class DeterministicProgramOverviewBuilder {
  const DeterministicProgramOverviewBuilder();

  ProgramOverviewResult build(ProgramOverviewInput input) {
    final t = input.trajectory;
    final buffer = StringBuffer()..writeln('Hi ${input.name}. Here is your program, built from your real numbers.');

    if (t.wasAdjusted && t.adjustmentReason != null) {
      buffer
        ..writeln()
        ..writeln(t.adjustmentReason);
    }

    buffer
      ..writeln()
      ..writeln('Your trajectory:');
    for (final m in t.milestones) {
      buffer.writeln('- ${m.label}: ${m.weightKg.toStringAsFixed(1)} kg (${_formatDate(m.date)})');
    }

    buffer
      ..writeln()
      ..writeln('Your weekly plan:');
    for (final day in input.weeklyPlan) {
      buffer.writeln('- ${day.title}: ${day.exerciseNames.join(', ')}');
    }

    buffer
      ..writeln()
      ..writeln('Nutrition target: ${input.nutrition.calorieTarget} kcal/day, '
          '${input.nutrition.proteinGrams.toStringAsFixed(0)}g protein, '
          '${input.nutrition.carbsGrams.toStringAsFixed(0)}g carbs, '
          '${input.nutrition.fatGrams.toStringAsFixed(0)}g fat.');

    buffer
      ..writeln()
      ..writeln('Track weekly: weight trend, steps, workouts completed, sleep.');

    return ProgramOverviewResult(overview: buffer.toString().trim(), source: 'deterministic');
  }

  String _formatDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
