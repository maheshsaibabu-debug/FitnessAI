import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../data/repositories/repository_providers.dart';

part 'dashboard_providers.g.dart';

@Riverpod(keepAlive: true)
Stream<UserProfile?> activeProfile(Ref ref) {
  return ref.watch(profileRepositoryProvider).watchActiveProfile();
}

@Riverpod(keepAlive: true)
Stream<Workout?> todaysWorkout(Ref ref) async* {
  final profile = await ref.watch(activeProfileProvider.future);
  if (profile == null) {
    yield null;
    return;
  }
  yield* ref.watch(workoutPlanRepositoryProvider).watchTodaysWorkout(profile.id, today: DateTime.now());
}

@Riverpod(keepAlive: true)
Stream<List<Workout>> upcomingWorkouts(Ref ref) async* {
  final profile = await ref.watch(activeProfileProvider.future);
  if (profile == null) {
    yield const [];
    return;
  }
  yield* ref.watch(workoutPlanRepositoryProvider).watchUpcomingWorkouts(profile.id, from: DateTime.now());
}
