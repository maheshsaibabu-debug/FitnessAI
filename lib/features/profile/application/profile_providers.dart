import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../dashboard/application/dashboard_providers.dart';

part 'profile_providers.g.dart';

/// The primary goal's full row (including `targetValue`/`targetDate`) —
/// [activeGoalsProvider] only exposes the set of goal type strings, not
/// this row, which the Profile screen needs to show/edit the target.
@Riverpod(keepAlive: true)
Future<FitnessGoal?> primaryGoal(Ref ref) async {
  final profile = await ref.watch(activeProfileProvider.future);
  if (profile == null) return null;
  return ref.watch(profileRepositoryProvider).primaryGoalRowOnce(profile.id);
}

/// The most recent fitness baseline test, if the user ever took one
/// (onboarding step 6, optional).
@Riverpod(keepAlive: true)
Future<FitnessBaseline?> latestBaseline(Ref ref) async {
  final profile = await ref.watch(activeProfileProvider.future);
  if (profile == null) return null;
  return ref.watch(profileRepositoryProvider).latestBaselineOnce(profile.id);
}
