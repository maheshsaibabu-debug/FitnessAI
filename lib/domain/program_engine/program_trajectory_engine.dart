class ProgramTrajectoryInput {
  const ProgramTrajectoryInput({
    required this.currentWeightKg,
    required this.goalWeightKg,
    required this.requestedTargetDate,
    required this.today,
  });

  final double currentWeightKg;
  final double goalWeightKg;
  final DateTime requestedTargetDate;
  final DateTime today;
}

class ProgramMilestone {
  const ProgramMilestone({required this.date, required this.weightKg, required this.label});
  final DateTime date;
  final double weightKg;
  final String label;
}

class ProgramTrajectory {
  const ProgramTrajectory({
    required this.startWeightKg,
    required this.goalWeightKg,
    required this.requestedTargetDate,
    required this.effectiveTargetDate,
    required this.wasAdjusted,
    required this.adjustmentReason,
    required this.weeklyRateKg,
    required this.milestones,
  });

  final double startWeightKg;
  final double goalWeightKg;
  final DateTime requestedTargetDate;
  final DateTime effectiveTargetDate;
  final bool wasAdjusted;
  final String? adjustmentReason;

  /// Signed: negative while losing, positive while gaining, 0 at goal.
  final double weeklyRateKg;
  final List<ProgramMilestone> milestones;
}

/// Turns a stated goal weight + target date into a real, safety-capped
/// weekly-rate trajectory with evenly-spaced milestones — deterministic,
/// the same "never delegated to the LLM" principle as every other number
/// in this app (docs/AI_ARCHITECTURE.md). The Program view's LLM
/// narrative explains this trajectory in prose; it never computes it,
/// and it can never make it less safe than what this engine allows.
class ProgramTrajectoryEngine {
  const ProgramTrajectoryEngine();

  /// Widely-cited safe upper bounds: up to ~1% of bodyweight/week for
  /// fat loss, about half that for a lean gain (muscle is built far
  /// slower than fat is lost).
  static const double maxLossRateFraction = 0.01;
  static const double maxGainRateFraction = 0.005;

  ProgramTrajectory compute(ProgramTrajectoryInput input) {
    final totalChange = input.goalWeightKg - input.currentWeightKg; // negative = loss
    final totalWeeks = _weeksBetween(input.today, input.requestedTargetDate);

    if (totalChange == 0 || totalWeeks <= 0) {
      return ProgramTrajectory(
        startWeightKg: input.currentWeightKg,
        goalWeightKg: input.goalWeightKg,
        requestedTargetDate: input.requestedTargetDate,
        effectiveTargetDate: input.requestedTargetDate,
        wasAdjusted: false,
        adjustmentReason: null,
        weeklyRateKg: 0,
        milestones: [ProgramMilestone(date: input.today, weightKg: input.currentWeightKg, label: 'Start')],
      );
    }

    final isLoss = totalChange < 0;
    final maxRateFraction = isLoss ? maxLossRateFraction : maxGainRateFraction;
    final maxWeeklyRateKg = input.currentWeightKg * maxRateFraction; // magnitude
    final requestedWeeklyRate = totalChange.abs() / totalWeeks;

    final double effectiveWeeklyRate;
    final DateTime effectiveTargetDate;
    final bool wasAdjusted;
    final String? reason;

    if (requestedWeeklyRate > maxWeeklyRateKg) {
      effectiveWeeklyRate = maxWeeklyRateKg;
      final neededWeeks = (totalChange.abs() / effectiveWeeklyRate).ceil();
      effectiveTargetDate = input.today.add(Duration(days: neededWeeks * 7));
      wasAdjusted = true;
      reason = isLoss
          ? 'Your requested pace was faster than a safe ${(maxLossRateFraction * 100).toStringAsFixed(0)}% of bodyweight per week, so the timeline was extended.'
          : 'Your requested pace was faster than a sustainable lean-gain rate, so the timeline was extended.';
    } else {
      effectiveWeeklyRate = requestedWeeklyRate;
      effectiveTargetDate = input.requestedTargetDate;
      wasAdjusted = false;
      reason = null;
    }

    final signedWeeklyRate = isLoss ? -effectiveWeeklyRate : effectiveWeeklyRate;

    return ProgramTrajectory(
      startWeightKg: input.currentWeightKg,
      goalWeightKg: input.goalWeightKg,
      requestedTargetDate: input.requestedTargetDate,
      effectiveTargetDate: effectiveTargetDate,
      wasAdjusted: wasAdjusted,
      adjustmentReason: reason,
      weeklyRateKg: signedWeeklyRate,
      milestones: _buildMilestones(
        start: input.today,
        end: effectiveTargetDate,
        startWeight: input.currentWeightKg,
        goalWeight: input.goalWeightKg,
      ),
    );
  }

  int _weeksBetween(DateTime a, DateTime b) => (b.difference(a).inDays / 7).round();

  List<ProgramMilestone> _buildMilestones({
    required DateTime start,
    required DateTime end,
    required double startWeight,
    required double goalWeight,
  }) {
    final totalDays = end.difference(start).inDays;
    if (totalDays <= 0) {
      return [ProgramMilestone(date: start, weightKg: _round1(startWeight), label: 'Start')];
    }

    final totalMonths = (totalDays / 30).round().clamp(1, 24);
    final milestones = <ProgramMilestone>[
      ProgramMilestone(date: start, weightKg: _round1(startWeight), label: 'Start'),
    ];
    for (var m = 1; m <= totalMonths; m++) {
      final t = m / totalMonths;
      final date = start.add(Duration(days: (totalDays * t).round()));
      final weight = startWeight + (goalWeight - startWeight) * t;
      milestones.add(ProgramMilestone(
        date: date,
        weightKg: _round1(weight),
        label: m == totalMonths ? 'Goal' : 'Month $m',
      ));
    }
    return milestones;
  }

  double _round1(double value) => double.parse(value.toStringAsFixed(1));
}
