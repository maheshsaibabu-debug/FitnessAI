import 'package:flutter/material.dart';

import '../../../shared/widgets/offline_banner.dart';

/// "Today" — answers "what should I do right now?" (product spec §21, §39).
/// Currently an honest empty state: the daily-plan generator and
/// accountability engine land in phases 6/10; this is real navigational
/// and layout scaffolding, not a mock of that future data.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Today')),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wb_sunny_outlined, size: 40, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 16),
                    Text(
                      'No plan yet',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Complete onboarding and a fitness baseline to get your first '
                      'adaptive plan. (Onboarding flow: implementation phase 5.)',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
