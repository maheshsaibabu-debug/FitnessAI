import 'package:flutter/material.dart';

/// Shown only for the brief moment it takes the router to read whether a
/// local profile already exists (a fast local DB query, not a network
/// call) before deciding between onboarding and the home shell.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Icon(Icons.fitness_center, size: 56, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
