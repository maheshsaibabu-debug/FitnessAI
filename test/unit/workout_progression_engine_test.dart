import 'package:fitness_companion/domain/progression_engine/workout_progression_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final engine = const WorkoutProgressionEngine();

  group('recommendNextReps — product-spec examples', () {
    test('all sets met target, low RPE -> increase by one', () {
      final rec = engine.recommendNextReps(targetReps: 6, actualReps: [6, 6, 6], rpe: 6);
      expect(rec.nextTarget, 7);
      expect(rec.direction, ProgressionDirection.increase);
    });

    test('sets missed badly at near-maximal RPE -> deload to average achieved', () {
      final rec = engine.recommendNextReps(targetReps: 8, actualReps: [8, 6, 5], rpe: 9);
      expect(rec.nextTarget, 6);
      expect(rec.direction, ProgressionDirection.decrease);
    });
  });

  group('recommendNextReps — additional cases', () {
    test('all sets met target but RPE near max -> hold, do not increase', () {
      final rec = engine.recommendNextReps(targetReps: 10, actualReps: [10, 10, 11], rpe: 9);
      expect(rec.nextTarget, 10);
      expect(rec.direction, ProgressionDirection.hold);
    });

    test('slight miss at moderate RPE -> hold and retry, not a deload', () {
      final rec = engine.recommendNextReps(targetReps: 8, actualReps: [8, 8, 7], rpe: 7);
      expect(rec.nextTarget, 8);
      expect(rec.direction, ProgressionDirection.hold);
    });

    test('big miss but RPE not maximal -> hold (not evidence the target is wrong)', () {
      final rec = engine.recommendNextReps(targetReps: 10, actualReps: [10, 5, 4], rpe: 6);
      expect(rec.nextTarget, 10);
      expect(rec.direction, ProgressionDirection.hold);
    });

    test('single-set exercise (e.g. plank) still works', () {
      final rec = engine.recommendNextReps(targetReps: 60, actualReps: [65], rpe: 6);
      expect(rec.nextTarget, 61);
      expect(rec.direction, ProgressionDirection.increase);
    });
  });

  group('recommendNextWeightKg', () {
    test('increases in the given plate increment', () {
      final rec = engine.recommendNextWeightKg(
        targetWeightKg: 60,
        actualWeightsKg: [60, 60, 60],
        rpe: 7,
        incrementKg: 2.5,
      );
      expect(rec.nextTarget, 62.5);
      expect(rec.direction, ProgressionDirection.increase);
    });

    test('deloads to the nearest plate increment below a failed near-max attempt', () {
      final rec = engine.recommendNextWeightKg(
        targetWeightKg: 100,
        actualWeightsKg: [100, 90, 85],
        rpe: 10,
        incrementKg: 2.5,
      );
      // average = 91.67 -> nearest 2.5kg increment = 92.5
      expect(rec.nextTarget, 92.5);
      expect(rec.direction, ProgressionDirection.decrease);
    });
  });
}
