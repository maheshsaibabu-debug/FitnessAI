import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Entry point of the onboarding flow (product spec §16-17) — leads into
/// [OnboardingFlowScreen], the real multi-step data-collection wizard.
class OnboardingWelcomeScreen extends StatelessWidget {
  const OnboardingWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 120,
                height: 120,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                child: Icon(Icons.fitness_center, size: 56, color: scheme.primary),
              ),
              const SizedBox(height: 32),
              Text(
                'Stronger\nHealthier\nHappier',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.15),
              ),
              const SizedBox(height: 16),
              Text(
                'Your personal fitness companion — offline and online.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
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
