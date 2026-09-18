import 'package:flutter/material.dart';

/// Placeholder for a feature whose backend isn't built yet in this phased
/// rollout (see docs/ARCHITECTURE.md §12). Deliberately honest rather than
/// faking data — no screen in this app shows a number or a completion
/// state that isn't backed by a real local write.
class ComingSoonScaffold extends StatelessWidget {
  const ComingSoonScaffold({super.key, required this.title, required this.phaseNote});

  final String title;
  final String phaseNote;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.construction_outlined, size: 40, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              Text(phaseNote, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
