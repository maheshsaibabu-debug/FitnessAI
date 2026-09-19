import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../data/local/health_repository.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../dashboard/application/dashboard_providers.dart';

part 'tracking_providers.g.dart';

@Riverpod(keepAlive: true)
Stream<StepRecord?> todaysSteps(Ref ref) async* {
  final profile = await ref.watch(activeProfileProvider.future);
  if (profile == null) {
    yield null;
    return;
  }
  yield* ref.watch(stepsRepositoryProvider).watchToday(profile.id);
}

@Riverpod(keepAlive: true)
Stream<List<StepRecord>> stepsHistory(Ref ref) async* {
  final profile = await ref.watch(activeProfileProvider.future);
  if (profile == null) {
    yield const [];
    return;
  }
  yield* ref.watch(stepsRepositoryProvider).watchHistory(profile.id, days: 7);
}

@Riverpod(keepAlive: true)
Stream<WeightLog?> latestWeight(Ref ref) async* {
  final profile = await ref.watch(activeProfileProvider.future);
  if (profile == null) {
    yield null;
    return;
  }
  yield* ref.watch(weightRepositoryProvider).watchLatest(profile.id);
}

@riverpod
class HealthConnectionController extends _$HealthConnectionController {
  @override
  Future<HealthPermissionStatus> build() {
    return ref.watch(healthRepositoryProvider).checkStepsPermission();
  }

  Future<void> requestAndSync() async {
    final healthRepo = ref.read(healthRepositoryProvider);
    final status = await healthRepo.requestStepsPermission();
    state = AsyncData(status);
    if (status == HealthPermissionStatus.granted) {
      await syncNow();
    }
  }

  Future<void> syncNow() async {
    final profile = await ref.read(profileRepositoryProvider).activeProfileOnce();
    if (profile == null) return;
    final healthRepo = ref.read(healthRepositoryProvider);
    final steps = await healthRepo.readTodaySteps();
    if (steps == null) return;
    await ref.read(stepsRepositoryProvider).upsertSteps(
          userId: profile.id,
          steps: steps,
          source: healthRepo.sourceLabel,
        );
  }
}
