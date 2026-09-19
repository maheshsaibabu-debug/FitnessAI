import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/category_icon_badge.dart';
import '../../application/onboarding_controller.dart';
import '../onboarding_options.dart';
import '../widgets/onboarding_step_scaffold.dart';

const Map<String, IconData> _goalIcons = {
  'fat_loss': Icons.local_fire_department,
  'muscle_gain': Icons.fitness_center,
  'weight_gain': Icons.trending_up,
  'maintain': Icons.balance,
  'strength': Icons.sports_gymnastics,
  'endurance': Icons.directions_run,
  'cardio': Icons.favorite,
  'mobility': Icons.self_improvement,
  'general': Icons.star_outline,
  'consistency': Icons.calendar_month,
};

class GoalsStep extends ConsumerWidget {
  const GoalsStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    return OnboardingStepScaffold(
      title: 'What are your goals?',
      subtitle: 'You can choose more than one — the first one you pick drives your plan and calorie target.',
      child: Column(
        children: [
          for (final (value, label) in kGoalOptions)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SelectableIconRow(
                icon: _goalIcons[value] ?? Icons.star_outline,
                categoryKey: value,
                label: label,
                selected: draft.goals.contains(value),
                onTap: () => controller.toggleGoal(value),
              ),
            ),
        ],
      ),
    );
  }
}
