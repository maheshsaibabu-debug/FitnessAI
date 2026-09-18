import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/coach/presentation/coach_screen.dart';
import '../../features/dashboard/presentation/home_shell.dart';
import '../../features/dashboard/presentation/today_screen.dart';
import '../../features/onboarding/presentation/onboarding_welcome_screen.dart';
import '../../features/progress/presentation/progress_screen.dart';
import '../../features/workouts/presentation/plan_screen.dart';
import '../../features/workouts/presentation/track_screen.dart';

part 'app_router.g.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingWelcomeScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (context, state) => const TodayScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/plan', builder: (context, state) => const PlanScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/track', builder: (context, state) => const TrackScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/progress', builder: (context, state) => const ProgressScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/coach', builder: (context, state) => const CoachScreen()),
          ]),
        ],
      ),
    ],
  );
}
