import '../fitness_engine/fitness_assessment_engine.dart';
import 'exercise_summary.dart';

class TrainingProfile {
  const TrainingProfile({
    required this.fitnessLevel,
    required this.availableEquipment,
    required this.daysPerWeek,
    required this.minutesPerSession,
    this.goals = const {},
  });

  final FitnessLevel fitnessLevel;

  /// Whatever the user has, e.g. {'dumbbells', 'pull_up_bar'}. 'none' is
  /// implicitly always available — bodyweight training needs no gear.
  final Set<String> availableEquipment;
  final int daysPerWeek;
  final int minutesPerSession;

  /// Raw goal-type strings (mirrors FitnessGoals.goalType) — used only to
  /// decide whether a cardio/HIIT day earns a slot in the weekly split.
  final Set<String> goals;
}

class GeneratedExercise {
  const GeneratedExercise({
    required this.exerciseId,
    required this.orderIndex,
    this.targetSets,
    this.targetReps,
    this.targetDurationSeconds,
    required this.restSeconds,
  });

  final String exerciseId;
  final int orderIndex;
  final int? targetSets;
  final int? targetReps;
  final int? targetDurationSeconds;
  final int restSeconds;
}

class GeneratedWorkout {
  const GeneratedWorkout({
    required this.dayOffset,
    required this.workoutType,
    required this.title,
    required this.estimatedMinutes,
    required this.exercises,
  });

  /// 0-based offset in days from the plan's start date.
  final int dayOffset;
  final String workoutType;
  final String title;
  final int estimatedMinutes;
  final List<GeneratedExercise> exercises;
}

class GeneratedPlan {
  const GeneratedPlan({required this.workouts});
  final List<GeneratedWorkout> workouts;
}

/// Builds a week of workouts from the user's profile and the bundled
/// exercise library — entirely offline, entirely deterministic. No two
/// runs with the same inputs and the same library ordering produce a
/// different plan, which is what makes this testable and what makes a
/// plan change explainable ("your availability changed" beats "the AI
/// felt like it").
class WorkoutGenerationEngine {
  const WorkoutGenerationEngine();

  GeneratedPlan generateWeek({
    required TrainingProfile profile,
    required List<ExerciseSummary> exerciseLibrary,
  }) {
    if (profile.daysPerWeek <= 0) return const GeneratedPlan(workouts: []);

    final preferCardioExtra = profile.goals.intersection(const {'fat_loss', 'endurance', 'cardio'}).isNotEmpty;
    final split = _splitForDays(profile.daysPerWeek, preferCardioExtra: preferCardioExtra);

    final workouts = <GeneratedWorkout>[];
    for (var day = 0; day < split.length; day++) {
      final workoutType = split[day];
      final exercises = _selectExercises(
        workoutType: workoutType,
        profile: profile,
        library: exerciseLibrary,
      );
      workouts.add(GeneratedWorkout(
        dayOffset: day,
        workoutType: workoutType,
        title: _titleFor(workoutType),
        estimatedMinutes: profile.minutesPerSession,
        exercises: exercises,
      ));
    }

    return GeneratedPlan(workouts: workouts);
  }

  List<String> _splitForDays(int days, {required bool preferCardioExtra}) {
    if (days <= 3) return List.filled(days, 'strength_full_body');
    if (days == 4) return const ['strength_upper', 'strength_lower', 'strength_upper', 'strength_lower'];

    const rotation = ['push', 'pull', 'legs'];
    final types = List.generate(days, (i) => rotation[i % rotation.length]);
    if (preferCardioExtra) {
      types[types.length - 1] = 'hiit';
    }
    return types;
  }

  static const Map<String, List<String>> _patternsByWorkoutType = {
    'strength_full_body': ['push', 'pull', 'legs', 'core'],
    'strength_upper': ['push', 'pull', 'push', 'pull'],
    'strength_lower': ['legs', 'legs', 'core'],
    'push': ['push', 'push', 'core'],
    'pull': ['pull', 'pull', 'core'],
    'legs': ['legs', 'legs', 'core'],
    'hiit': ['hiit', 'hiit', 'hiit', 'hiit'],
    'cardio': ['cardio'],
  };

  List<GeneratedExercise> _selectExercises({
    required String workoutType,
    required TrainingProfile profile,
    required List<ExerciseSummary> library,
  }) {
    final desiredPatterns = _patternsByWorkoutType[workoutType] ?? const ['push', 'pull', 'legs', 'core'];
    final usableEquipment = {...profile.availableEquipment, 'none'};
    final targets = _targetsForLevel(profile.fitnessLevel, isHiit: workoutType == 'hiit');

    final used = <String>{};
    final selected = <GeneratedExercise>[];
    var order = 0;

    for (final pattern in desiredPatterns) {
      final candidates = library.where((e) {
        if (used.contains(e.id)) return false;
        if (_movementPattern(e) != pattern) return false;
        if (!e.equipment.every(usableEquipment.contains)) return false;
        return _levelRank(e.difficulty) <= _levelRank(_levelName(profile.fitnessLevel));
      }).toList()
        ..sort((a, b) => a.id.compareTo(b.id)); // deterministic ordering

      if (candidates.isEmpty) continue;
      final chosen = candidates.first;
      used.add(chosen.id);

      selected.add(GeneratedExercise(
        exerciseId: chosen.id,
        orderIndex: order++,
        targetSets: targets.sets,
        targetReps: workoutType == 'hiit' ? null : targets.reps,
        targetDurationSeconds: workoutType == 'hiit' ? targets.durationSeconds : null,
        restSeconds: targets.restSeconds,
      ));
    }

    return selected;
  }

  String _movementPattern(ExerciseSummary e) {
    if (e.category == 'hiit') return 'hiit';
    if (e.category == 'cardio') return 'cardio';
    if (e.category == 'mobility') return 'mobility';
    if (e.category == 'core') return 'core';

    final muscles = e.primaryMuscles.map((m) => m.toLowerCase()).toSet();
    const pushMuscles = {'chest', 'shoulders', 'triceps'};
    const pullMuscles = {'back', 'biceps'};
    const legMuscles = {'quadriceps', 'hamstrings', 'glutes', 'calves'};

    if (muscles.any(legMuscles.contains)) return 'legs';
    if (muscles.any(pushMuscles.contains)) return 'push';
    if (muscles.any(pullMuscles.contains)) return 'pull';
    return 'core';
  }

  int _levelRank(String difficulty) => switch (difficulty) {
        'beginner' => 0,
        'intermediate' => 1,
        'advanced' => 2,
        _ => 0,
      };

  String _levelName(FitnessLevel level) => switch (level) {
        FitnessLevel.beginner => 'beginner',
        FitnessLevel.intermediate => 'intermediate',
        FitnessLevel.advanced => 'advanced',
      };

  ({int sets, int reps, int durationSeconds, int restSeconds}) _targetsForLevel(
    FitnessLevel level, {
    required bool isHiit,
  }) {
    if (isHiit) {
      return switch (level) {
        FitnessLevel.beginner => (sets: 3, reps: 0, durationSeconds: 20, restSeconds: 20),
        FitnessLevel.intermediate => (sets: 4, reps: 0, durationSeconds: 30, restSeconds: 15),
        FitnessLevel.advanced => (sets: 5, reps: 0, durationSeconds: 40, restSeconds: 15),
      };
    }
    return switch (level) {
      FitnessLevel.beginner => (sets: 2, reps: 12, durationSeconds: 0, restSeconds: 60),
      FitnessLevel.intermediate => (sets: 3, reps: 10, durationSeconds: 0, restSeconds: 75),
      FitnessLevel.advanced => (sets: 4, reps: 8, durationSeconds: 0, restSeconds: 90),
    };
  }

  String _titleFor(String workoutType) => switch (workoutType) {
        'strength_full_body' => 'Full Body Strength',
        'strength_upper' => 'Upper Body Strength',
        'strength_lower' => 'Lower Body Strength',
        'push' => 'Push Day',
        'pull' => 'Pull Day',
        'legs' => 'Leg Day',
        'hiit' => 'HIIT',
        'cardio' => 'Cardio',
        _ => 'Workout',
      };
}
