import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../data/repositories/nutrition_repository.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../domain/motivation_engine/motivation_engine.dart';
import '../../../domain/workout_engine/workout_generation_engine.dart';
import '../../../shared/widgets/category_icon_badge.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../nutrition/application/diet_provider.dart';
import '../../tracking/application/tracking_providers.dart';
import '../application/dashboard_providers.dart';

const _defaultStepsTarget = 8000;

const _skipReasons = [
  ('no_time', 'No time'),
  ('too_tired', 'Too tired'),
  ('busy', 'Busy'),
  ('sore', 'Sore'),
  ('no_equipment', 'No equipment'),
  ('not_motivated', 'Not motivated'),
  ('other', 'Other'),
];

/// "Today" — answers "what should I do right now?" (product spec §21,
/// §39). Every row shown here is real data (workout from the generated
/// plan, steps from StepsRepository) — nothing invented to fill out the
/// layout.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaysWorkout = ref.watch(todaysWorkoutProvider);
    final todaysSteps = ref.watch(todaysStepsProvider);
    final todaysDiet = ref.watch(todaysDietProvider);
    final profile = ref.watch(activeProfileProvider).valueOrNull;
    final goals = ref.watch(activeGoalsProvider).valueOrNull ?? const {};
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    '${_greeting()}${profile != null ? ', ${profile.name}' : ''}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    const MotivationEngine().dailyQuote(DateTime.now()),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Today's Plan", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 16),
                          todaysWorkout.when(
                            loading: () => const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: LinearProgressIndicator(),
                            ),
                            error: (e, st) => Text('Could not load today\'s plan: $e'),
                            data: (workout) => _WorkoutRow(workout: workout, goals: goals),
                          ),
                          const SizedBox(height: 14),
                          todaysSteps.when(
                            loading: () => const SizedBox.shrink(),
                            error: (e, st) => const SizedBox.shrink(),
                            data: (record) => _InfoRow(
                              icon: Icons.directions_walk,
                              categoryKey: 'steps',
                              label: 'Steps',
                              value: record == null
                                  ? 'Not logged yet'
                                  : '${record.steps}${record.target != null ? ' / ${record.target}' : ''}',
                            ),
                          ),
                          const SizedBox(height: 14),
                          todaysDiet.when(
                            loading: () => const SizedBox.shrink(),
                            error: (e, st) => const SizedBox.shrink(),
                            data: (meals) {
                              if (meals.isEmpty) return const SizedBox.shrink();
                              final confirmed = meals.where((m) => m.eaten != null).length;
                              final totalCalories = meals.fold<double>(0, (sum, m) => sum + m.meal.calories);
                              final macros = _MacroSplit.fromMeals(meals);
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  CategoryIconBadge(icon: Icons.restaurant, categoryKey: 'diet', size: 40),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Diet', style: Theme.of(context).textTheme.bodyLarge),
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            '$confirmed of ${meals.length} meals confirmed',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${totalCalories.round()} kcal',
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  if (macros.hasData) ...[
                                    const SizedBox(width: 8),
                                    _MacroMiniRings(macros: macros),
                                  ],
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  todaysWorkout.valueOrNull != null
                      ? _WorkoutActions(workout: todaysWorkout.value!)
                      : const SizedBox.shrink(),
                  const SizedBox(height: 20),
                  _DailyVitalsCard(steps: todaysSteps.valueOrNull, diet: todaysDiet.valueOrNull ?? const []),
                  const SizedBox(height: 20),
                  const _MotivationTipCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.categoryKey, required this.label, required this.value, this.subtitle});

  final IconData icon;
  final String categoryKey;
  final String label;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CategoryIconBadge(icon: icon, categoryKey: categoryKey, size: 40),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyLarge),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
        Text(value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _WorkoutRow extends StatelessWidget {
  const _WorkoutRow({required this.workout, required this.goals});
  final Workout? workout;
  final Set<String> goals;

  @override
  Widget build(BuildContext context) {
    if (workout == null) {
      return _InfoRow(icon: Icons.self_improvement, categoryKey: 'rest', label: 'Rest day', value: 'Nothing scheduled');
    }
    return _InfoRow(
      icon: Icons.fitness_center,
      categoryKey: 'workout',
      label: workout!.title,
      value: '${workout!.estimatedMinutes ?? '—'} min',
      subtitle: workoutFocusSummary(workoutType: workout!.workoutType, goals: goals),
    );
  }
}

class _WorkoutActions extends ConsumerWidget {
  const _WorkoutActions({required this.workout});
  final Workout workout;

  bool get _isDone => workout.status == 'completed' || workout.status == 'skipped';

  Future<void> _skip(BuildContext context, WidgetRef ref) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What\'s stopping you?', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (value, label) in _skipReasons)
                    ActionChip(label: Text(label), onPressed: () => Navigator.of(context).pop(value)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (reason == null) return;

    final profile = await ref.read(profileRepositoryProvider).activeProfileOnce();
    if (profile == null) return;
    await ref.read(workoutExecutionRepositoryProvider).completeWorkout(
          workoutId: workout.id,
          userId: profile.id,
          status: 'skipped',
          skipReasonCode: reason,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_isDone) {
      return Text(
        workout.status == 'completed' ? 'Completed — nice work.' : 'Skipped for today.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _skip(context, ref),
            child: const Text('Skip'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: () => context.push('/workout/${workout.id}'),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Workout'),
          ),
        ),
      ],
    );
  }
}

/// Steps (from Health Connect/HealthKit or manual entry) and today's
/// logged calorie/macro split side by side — the two "at a glance" numbers
/// beyond the plan itself. Both come from the same repositories the Track
/// and Diet tabs use; nothing here is computed just for this card.
class _DailyVitalsCard extends StatelessWidget {
  const _DailyVitalsCard({required this.steps, required this.diet});

  final StepRecord? steps;
  final List<DietMeal> diet;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily Vitals', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _StepsVital(steps: steps)),
                  const SizedBox(width: 20),
                  const VerticalDivider(width: 1),
                  const SizedBox(width: 20),
                  Expanded(child: _CaloriesVital(diet: diet)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepsVital extends StatelessWidget {
  const _StepsVital({required this.steps});
  final StepRecord? steps;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = steps?.steps ?? 0;
    final target = steps?.target ?? _defaultStepsTarget;
    final progress = target <= 0 ? 0.0 : (count / target).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.directions_walk, color: scheme.primary, size: 20),
            const SizedBox(width: 6),
            Text('Steps', style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
        const SizedBox(height: 12),
        Text('$count', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: scheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(scheme.primary),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$count / $target steps',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Today's logged protein/carbs/fat as a share of total macro calories
/// (4 kcal/g for protein and carbs, 9 kcal/g for fat) — the standard
/// conversion, not an invented weighting. All-zero when nothing's logged.
class _MacroSplit {
  const _MacroSplit({required this.protein, required this.carbs, required this.fat});

  factory _MacroSplit.fromMeals(List<DietMeal> meals) {
    final proteinKcal = meals.fold<double>(0, (sum, m) => sum + m.meal.proteinGrams * 4);
    final carbsKcal = meals.fold<double>(0, (sum, m) => sum + m.meal.carbsGrams * 4);
    final fatKcal = meals.fold<double>(0, (sum, m) => sum + m.meal.fatGrams * 9);
    final total = proteinKcal + carbsKcal + fatKcal;
    if (total <= 0) return const _MacroSplit(protein: 0, carbs: 0, fat: 0);
    return _MacroSplit(protein: proteinKcal / total, carbs: carbsKcal / total, fat: fatKcal / total);
  }

  final double protein;
  final double carbs;
  final double fat;

  bool get hasData => protein + carbs + fat > 0;

  static const proteinColor = Color(0xFFEC4899);
  static const carbsColor = Color(0xFF2FAE66);
  static const fatColor = Color(0xFF8B5CF6);
}

class _CaloriesVital extends StatelessWidget {
  const _CaloriesVital({required this.diet});
  final List<DietMeal> diet;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalCalories = diet.fold<double>(0, (sum, m) => sum + m.meal.calories);
    final macros = _MacroSplit.fromMeals(diet);
    final confirmed = diet.where((m) => m.eaten != null).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.local_fire_department, color: scheme.secondary, size: 20),
            const SizedBox(width: 6),
            Text('Calories', style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: SizedBox(
            width: 108,
            height: 108,
            child: CustomPaint(
              painter: _MacroDonutPainter(
                proteinShare: macros.protein,
                carbsShare: macros.carbs,
                fatShare: macros.fat,
                proteinColor: _MacroSplit.proteinColor,
                carbsColor: _MacroSplit.carbsColor,
                fatColor: _MacroSplit.fatColor,
                trackColor: scheme.surfaceContainerHighest,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${totalCalories.round()}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    Text('kcal', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (macros.hasData)
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              _MacroLegend(label: 'P', percent: macros.protein, color: _MacroSplit.proteinColor),
              _MacroLegend(label: 'C', percent: macros.carbs, color: _MacroSplit.carbsColor),
              _MacroLegend(label: 'F', percent: macros.fat, color: _MacroSplit.fatColor),
            ],
          ),
        const SizedBox(height: 6),
        Text(
          'Logged meals: $confirmed of ${diet.length}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// The three small per-macro rings appended to the Diet row itself — a
/// compact preview of the same split shown in full in the Daily Vitals
/// calories donut below.
class _MacroMiniRings extends StatelessWidget {
  const _MacroMiniRings({required this.macros});
  final _MacroSplit macros;

  @override
  Widget build(BuildContext context) {
    if (!macros.hasData) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MiniRing(label: 'P', percent: macros.protein, color: _MacroSplit.proteinColor),
        const SizedBox(width: 6),
        _MiniRing(label: 'C', percent: macros.carbs, color: _MacroSplit.carbsColor),
        const SizedBox(width: 6),
        _MiniRing(label: 'F', percent: macros.fat, color: _MacroSplit.fatColor),
      ],
    );
  }
}

class _MiniRing extends StatelessWidget {
  const _MiniRing({required this.label, required this.percent, required this.color});
  final String label;
  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 26,
          height: 26,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: percent,
                strokeWidth: 3,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(color),
              ),
              Text(
                '${(percent * 100).round()}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 8),
              ),
            ],
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 8)),
      ],
    );
  }
}

class _MacroLegend extends StatelessWidget {
  const _MacroLegend({required this.label, required this.percent, required this.color});
  final String label;
  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text('$label:${(percent * 100).round()}%', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _MacroDonutPainter extends CustomPainter {
  _MacroDonutPainter({
    required this.proteinShare,
    required this.carbsShare,
    required this.fatShare,
    required this.proteinColor,
    required this.carbsColor,
    required this.fatColor,
    required this.trackColor,
  });

  final double proteinShare;
  final double carbsShare;
  final double fatShare;
  final Color proteinColor;
  final Color carbsColor;
  final Color fatColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const strokeWidth = 12.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(rect.deflate(strokeWidth / 2), 0, 2 * math.pi, false, paint..color = trackColor);

    if (proteinShare + carbsShare + fatShare <= 0) return;

    var start = -math.pi / 2;
    for (final (share, color) in [(proteinShare, proteinColor), (carbsShare, carbsColor), (fatShare, fatColor)]) {
      if (share <= 0) continue;
      final sweep = 2 * math.pi * share;
      canvas.drawArc(rect.deflate(strokeWidth / 2), start, sweep, false, paint..color = color);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _MacroDonutPainter oldDelegate) =>
      oldDelegate.proteinShare != proteinShare ||
      oldDelegate.carbsShare != carbsShare ||
      oldDelegate.fatShare != fatShare;
}

/// A genuine, rotating fitness/nutrition tip (see MotivationEngine) — kept
/// separate from the daily quote shown under the greeting, which is
/// motivational copy rather than actionable advice.
class _MotivationTipCard extends StatelessWidget {
  const _MotivationTipCard();

  @override
  Widget build(BuildContext context) {
    final tip = const MotivationEngine().dailyTip(DateTime.now());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CategoryIconBadge(icon: Icons.lightbulb, categoryKey: 'tip', size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'Tip of the Day: ', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                        TextSpan(text: tip, style: Theme.of(context).textTheme.bodyLarge),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
