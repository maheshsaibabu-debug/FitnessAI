import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/onboarding_controller.dart';
import '../onboarding_options.dart';
import '../widgets/onboarding_step_scaffold.dart';

class GoalsStep extends ConsumerWidget {
  const GoalsStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    return OnboardingStepScaffold(
      title: 'What\'s your main goal?',
      subtitle: 'Pick the one that matters most right now — your plan is built around it.',
      child: ChoiceChipGroup(
        options: kGoalOptions,
        selected: draft.primaryGoal,
        onSelected: controller.updatePrimaryGoal,
      ),
    );
  }
}
