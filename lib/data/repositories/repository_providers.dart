import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/database_provider.dart';
import '../local/exercise_library_seeder.dart';
import 'profile_repository.dart';
import 'workout_plan_repository.dart';

part 'repository_providers.g.dart';

@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) => ProfileRepository(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
ExerciseLibrarySeeder exerciseLibrarySeeder(Ref ref) => ExerciseLibrarySeeder(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
WorkoutPlanRepository workoutPlanRepository(Ref ref) {
  return WorkoutPlanRepository(ref.watch(appDatabaseProvider), ref.watch(exerciseLibrarySeederProvider));
}
