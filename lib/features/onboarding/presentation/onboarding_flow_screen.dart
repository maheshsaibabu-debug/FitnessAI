import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/onboarding_controller.dart';
import 'steps/availability_step.dart';
import 'steps/baseline_step.dart';
import 'steps/goals_step.dart';
import 'steps/level_step.dart';
import 'steps/nutrition_step.dart';
import 'steps/personal_step.dart';
import 'steps/review_step.dart';

const _stepTitles = ['Personal', 'Goals', 'Level', 'Availability', 'Nutrition', 'Baseline', 'Review'];

class OnboardingFlowScreen extends ConsumerStatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  ConsumerState<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends ConsumerState<OnboardingFlowScreen> {
  final _pageController = PageController();
  int _index = 0;

  static const _steps = <Widget>[
    PersonalStep(),
    GoalsStep(),
    LevelStep(),
    AvailabilityStep(),
    NutritionStep(),
    BaselineStep(),
    ReviewStep(),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool _isCurrentStepValid(int index) {
    final draft = ref.watch(onboardingControllerProvider);
    return switch (index) {
      0 => draft.isPersonalStepValid,
      1 => draft.isGoalsStepValid,
      2 => draft.isLevelStepValid,
      3 => draft.isAvailabilityStepValid,
      _ => true, // nutrition and baseline are optional; review gates its own submit
    };
  }

  void _goToStep(int index) {
    setState(() => _index = index);
    _pageController.animateToPage(index, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final isLastStep = _index == _steps.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_stepTitles[_index]} (${_index + 1}/${_steps.length})'),
        leading: _index == 0
            ? null
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => _goToStep(_index - 1)),
      ),
      body: GestureDetector(
        // Tapping anywhere outside a text field should dismiss the
        // keyboard — otherwise it can linger and obscure the Next button
        // on smaller screens, which is exactly the kind of thing a real
        // user would get stuck on.
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            LinearProgressIndicator(value: (_index + 1) / _steps.length),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _index = i),
                children: _steps,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isLastStep
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: _isCurrentStepValid(_index) ? () => _goToStep(_index + 1) : null,
                child: const Text('Next'),
              ),
            ),
    );
  }
}
