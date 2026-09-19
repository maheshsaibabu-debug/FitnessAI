import 'package:fitness_companion/ai/fitness_context.dart';
import 'package:fitness_companion/ai/providers/rule_based_fallback_provider.dart';
import 'package:flutter_test/flutter_test.dart';

FitnessContext _context({
  int currentStreak = 0,
  int workoutsCompletedLast14Days = 0,
  String? nextWorkoutTitle,
}) {
  return FitnessContext(
    name: 'Test',
    goals: const {'general'},
    fitnessLevel: 'beginner',
    currentStreak: currentStreak,
    workoutsCompletedLast14Days: workoutsCompletedLast14Days,
    workoutsSkippedLast14Days: 0,
    workoutsScheduledLast14Days: 0,
    nextWorkoutTitle: nextWorkoutTitle,
  );
}

void main() {
  const provider = RuleBasedFallbackProvider();

  test('never throws and always returns a rule_based-sourced reply', () async {
    final response = await provider.respond(_context(), 'What should I eat today?');
    expect(response.source, 'rule_based');
    expect(response.message, isNotEmpty);
    expect(response.model, isNull);
  });

  test('mentions the next scheduled workout when one exists', () async {
    final response = await provider.respond(_context(nextWorkoutTitle: 'Push Day'), 'hi');
    expect(response.message, contains('Push Day'));
  });

  test('falls back to streak framing when there is no next workout but a live streak', () async {
    final response = await provider.respond(_context(currentStreak: 4), 'hi');
    expect(response.message, contains('4'));
  });

  test('falls back to a generic pointer when there is no data to reference', () async {
    final response = await provider.respond(_context(), 'hi');
    expect(response.message, contains('Plan tab'));
  });
}
