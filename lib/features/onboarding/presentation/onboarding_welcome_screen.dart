import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Entry point of the onboarding flow (product spec §16-17) — leads into
/// [OnboardingFlowScreen], the real multi-step data-collection wizard.
class OnboardingWelcomeScreen extends StatelessWidget {
  const OnboardingWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.fitness_center, size: 56, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                'Fitness Companion',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Plan. Do. Track. Check in. Adapt.\nWorks fully offline — sync is a bonus, not a requirement.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 40),
              FilledButton(
                onPressed: () => context.push('/onboarding/flow'),
                child: const Text('Get started'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
