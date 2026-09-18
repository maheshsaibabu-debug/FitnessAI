import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/coach/presentation/coach_screen.dart';
import '../../features/dashboard/presentation/home_shell.dart';
import '../../features/dashboard/presentation/today_screen.dart';
import '../../features/onboarding/presentation/onboarding_flow_screen.dart';
import '../../features/onboarding/presentation/onboarding_welcome_screen.dart';
import '../../features/progress/presentation/progress_screen.dart';
import '../../features/workouts/presentation/plan_screen.dart';
import '../../features/workouts/presentation/track_screen.dart';
import '../../shared/widgets/splash_screen.dart';
import '../database/app_database.dart';
import '../database/database_provider.dart';

part 'app_router.g.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Tracks whether a local profile with onboarding finished exists, fed by
/// a live Drift query rather than a one-off read, so completing
/// onboarding immediately unlocks the home shell without an app restart.
/// `null` means "not yet known" — the router holds on `/splash` for that
/// brief window instead of guessing.
class _OnboardingStatus extends ValueNotifier<bool?> {
  _OnboardingStatus(AppDatabase db) : super(null) {
    _subscription = db.select(db.userProfiles).watchSingleOrNull().listen((profile) {
      value = profile?.onboardingCompleted ?? false;
    });
  }

  late final StreamSubscription<UserProfile?> _subscription;

  void disposeStatus() {
    _subscription.cancel();
    dispose();
  }
}

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final onboardingStatus = _OnboardingStatus(db);
  ref.onDispose(onboardingStatus.disposeStatus);

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: onboardingStatus,
    redirect: (context, state) {
      final completed = onboardingStatus.value;
      final loc = state.matchedLocation;

      if (completed == null) {
        return loc == '/splash' ? null : '/splash';
      }
      if (!completed) {
        return loc.startsWith('/onboarding') ? null : '/onboarding';
      }
      // Onboarding is done: never show splash/onboarding again.
      if (loc == '/splash' || loc.startsWith('/onboarding')) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingWelcomeScreen(),
        routes: [
          GoRoute(path: 'flow', builder: (context, state) => const OnboardingFlowScreen()),
        ],
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

  return router;
}
