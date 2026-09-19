/// The bounded context sent to the AI gateway — docs/AI_ARCHITECTURE.md's
/// `FitnessContextResolver` contract: summarized trends and the numbers
/// the deterministic engines already computed, never raw historical rows
/// and never anything the LLM could mistake for permission to invent its
/// own plan or targets. Every field here is something the app can
/// actually back up from real local data — nothing is guessed to fill
/// out the shape (e.g. there's no "recovery check-in" or food-logging
/// feature yet, so those fields simply don't exist here rather than
/// being faked).
class FitnessContext {
  const FitnessContext({
    required this.name,
    required this.goals,
    required this.fitnessLevel,
    required this.currentStreak,
    required this.workoutsCompletedLast14Days,
    required this.workoutsSkippedLast14Days,
    required this.workoutsScheduledLast14Days,
    this.nextWorkoutTitle,
    this.nextWorkoutDate,
    this.lastWorkoutTitle,
    this.lastWorkoutStatus,
    this.stepAverageLast7Days,
    this.latestWeightKg,
    this.weightTrendKgPerWeek,
    this.calorieTarget,
    this.proteinGrams,
  });

  final String name;
  final Set<String> goals;
  final String fitnessLevel;

  final int currentStreak;
  final int workoutsCompletedLast14Days;
  final int workoutsSkippedLast14Days;
  final int workoutsScheduledLast14Days;

  final String? nextWorkoutTitle;
  final DateTime? nextWorkoutDate;
  final String? lastWorkoutTitle;
  final String? lastWorkoutStatus;

  final double? stepAverageLast7Days;
  final double? latestWeightKg;

  /// kg/week, positive = gaining, negative = losing. Null until there are
  /// at least two weight logs to compare.
  final double? weightTrendKgPerWeek;

  final int? calorieTarget;
  final double? proteinGrams;

  /// Flat, LLM-friendly shape — deliberately not a dump of database rows.
  Map<String, Object?> toJson() => {
        'name': name,
        'goals': goals.toList(),
        'fitnessLevel': fitnessLevel,
        'currentStreakDays': currentStreak,
        'workoutsCompletedLast14Days': workoutsCompletedLast14Days,
        'workoutsSkippedLast14Days': workoutsSkippedLast14Days,
        'workoutsScheduledLast14Days': workoutsScheduledLast14Days,
        if (nextWorkoutTitle != null) 'nextWorkoutTitle': nextWorkoutTitle,
        if (nextWorkoutDate != null) 'nextWorkoutDate': nextWorkoutDate!.toIso8601String(),
        if (lastWorkoutTitle != null) 'lastWorkoutTitle': lastWorkoutTitle,
        if (lastWorkoutStatus != null) 'lastWorkoutStatus': lastWorkoutStatus,
        if (stepAverageLast7Days != null) 'stepAverageLast7Days': stepAverageLast7Days!.round(),
        if (latestWeightKg != null) 'latestWeightKg': latestWeightKg,
        if (weightTrendKgPerWeek != null) 'weightTrendKgPerWeek': weightTrendKgPerWeek,
        if (calorieTarget != null) 'calorieTargetPerDay': calorieTarget,
        if (proteinGrams != null) 'proteinTargetGramsPerDay': proteinGrams,
      };
}
