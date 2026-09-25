import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/repositories/nutrition_repository.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../dashboard/application/dashboard_providers.dart';

part 'diet_provider.g.dart';

@riverpod
Future<List<DietMeal>> todaysDiet(Ref ref) async {
  final profile = await ref.watch(activeProfileProvider.future);
  if (profile == null) return const [];
  return ref.watch(nutritionRepositoryProvider).todaysDiet(profile.id);
}
