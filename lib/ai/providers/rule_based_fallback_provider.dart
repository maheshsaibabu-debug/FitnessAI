import '../../domain/motivation_engine/motivation_engine.dart';
import '../ai_provider.dart';
import '../fitness_context.dart';

/// docs/AI_ARCHITECTURE.md's RuleBasedFallbackProvider: pure Dart, always
/// available, no network. This is what the coach falls back to when the
/// cloud gateway can't be reached — never a bare "AI unavailable" (the
/// doc's explicit rule), always a real, useful sentence built from
/// numbers the app actually has.
class RuleBasedFallbackProvider implements AiProvider {
  const RuleBasedFallbackProvider();

  @override
  Future<CoachResponse> respond(FitnessContext context, String userMessage) async {
    final fact = _mostRelevantFact(context);
    final message = "Your coach is offline right now, but here's what I can tell you: $fact";
    return CoachResponse(message: message, source: 'rule_based');
  }

  String _mostRelevantFact(FitnessContext c) {
    if (c.nextWorkoutTitle != null) {
      return '${c.nextWorkoutTitle} is next on your plan.';
    }
    if (c.currentStreak > 0) {
      return const MotivationEngine().messageFor(
        MotivationContext(moment: MotivationMoment.streakAtRisk, currentStreak: c.currentStreak),
      );
    }
    if (c.workoutsCompletedLast14Days > 0) {
      return 'You\'ve completed ${c.workoutsCompletedLast14Days} workout'
          '${c.workoutsCompletedLast14Days == 1 ? '' : 's'} in the last two weeks — check the Plan tab for what\'s next.';
    }
    return 'Check the Plan tab for what\'s scheduled next.';
  }
}
