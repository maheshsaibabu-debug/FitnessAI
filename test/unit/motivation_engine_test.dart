import 'package:fitness_companion/domain/motivation_engine/motivation_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final engine = const MotivationEngine();

  test('morning message matches the product spec example', () {
    final msg = engine.messageFor(const MotivationContext(moment: MotivationMoment.morningPlanReady));
    expect(msg, 'Your plan is ready.');
  });

  test('mid-week progress message matches the product spec example when one workout remains', () {
    final msg = engine.messageFor(const MotivationContext(
      moment: MotivationMoment.midWeekProgress,
      workoutsRemainingThisWeek: 1,
    ));
    expect(msg, 'You\'re one workout away from your weekly target.');
  });

  test('comeback message matches the product spec example', () {
    final msg = engine.messageFor(const MotivationContext(moment: MotivationMoment.comebackAfterBreak));
    expect(msg, 'Let\'s restart with a simple 10-minute session.');
  });

  test('celebration message never shames, only counts', () {
    final msg = engine.messageFor(const MotivationContext(
      moment: MotivationMoment.weeklyCelebration,
      workoutsCompletedThisWeek: 5,
    ));
    expect(msg, contains('5 workouts completed'));
  });

  test('streak-ended message reframes as progress retained, not a failure', () {
    expect(engine.streakEndedMessage(), 'Your streak ended. Your progress didn\'t.');
  });

  test('no message in this engine contains guilt/shame language', () {
    const bannedWords = ['fail', 'lazy', 'should have', 'disappointing', 'bad'];
    final allMessages = [
      engine.messageFor(const MotivationContext(moment: MotivationMoment.morningPlanReady)),
      engine.messageFor(const MotivationContext(moment: MotivationMoment.midWeekProgress, workoutsRemainingThisWeek: 2)),
      engine.messageFor(const MotivationContext(moment: MotivationMoment.weeklyCelebration, workoutsCompletedThisWeek: 3)),
      engine.messageFor(const MotivationContext(moment: MotivationMoment.comebackAfterBreak)),
      engine.messageFor(const MotivationContext(moment: MotivationMoment.streakAtRisk, currentStreak: 4)),
      engine.streakEndedMessage(),
    ];
    for (final message in allMessages) {
      for (final banned in bannedWords) {
        expect(message.toLowerCase().contains(banned), isFalse, reason: '"$message" contains banned word "$banned"');
      }
    }
  });

  test('dailyQuote is stable within a day and changes the next day', () {
    final today = engine.dailyQuote(DateTime(2026, 3, 15));
    final sameDayLater = engine.dailyQuote(DateTime(2026, 3, 15, 23, 59));
    final tomorrow = engine.dailyQuote(DateTime(2026, 3, 16));

    expect(today, sameDayLater);
    expect(today, isNot(tomorrow));
  });

  test('dailyQuote never indexes out of range, including Dec 31 of a leap year', () {
    expect(() => engine.dailyQuote(DateTime(2028, 12, 31)), returnsNormally);
  });
}
