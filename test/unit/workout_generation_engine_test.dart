import 'package:fitness_companion/domain/fitness_engine/fitness_assessment_engine.dart';
import 'package:fitness_companion/domain/workout_engine/exercise_summary.dart';
import 'package:fitness_companion/domain/workout_engine/workout_generation_engine.dart';
import 'package:flutter_test/flutter_test.dart';

const _library = [
  ExerciseSummary(id: 'push-up', name: 'Push-up', category: 'bodyweight', primaryMuscles: ['chest', 'triceps'], equipment: ['none'], difficulty: 'beginner'),
  ExerciseSummary(id: 'diamond-push-up', name: 'Diamond Push-up', category: 'bodyweight', primaryMuscles: ['triceps'], equipment: ['none'], difficulty: 'advanced'),
  ExerciseSummary(id: 'pull-up', name: 'Pull-up', category: 'bodyweight', primaryMuscles: ['back', 'biceps'], equipment: ['pull_up_bar'], difficulty: 'intermediate'),
  ExerciseSummary(id: 'inverted-row', name: 'Inverted Row', category: 'bodyweight', primaryMuscles: ['back'], equipment: ['bench'], difficulty: 'beginner'),
  ExerciseSummary(id: 'squat', name: 'Bodyweight Squat', category: 'bodyweight', primaryMuscles: ['quadriceps', 'glutes'], equipment: ['none'], difficulty: 'beginner'),
  ExerciseSummary(id: 'barbell-squat', name: 'Barbell Squat', category: 'strength', primaryMuscles: ['quadriceps'], equipment: ['barbell'], difficulty: 'advanced'),
  ExerciseSummary(id: 'plank', name: 'Plank', category: 'core', primaryMuscles: ['core'], equipment: ['none'], difficulty: 'beginner'),
  ExerciseSummary(id: 'burpee', name: 'Burpee', category: 'hiit', primaryMuscles: ['full_body'], equipment: ['none'], difficulty: 'intermediate'),
  ExerciseSummary(id: 'kettlebell-swing', name: 'Kettlebell Swing', category: 'hiit', primaryMuscles: ['glutes'], equipment: ['kettlebell'], difficulty: 'intermediate'),
];

void main() {
  final engine = const WorkoutGenerationEngine();

  test('generates exactly one workout per day of the week requested', () {
    final plan = engine.generateWeek(
      profile: const TrainingProfile(
        fitnessLevel: FitnessLevel.beginner,
        availableEquipment: {},
        daysPerWeek: 3,
        minutesPerSession: 30,
      ),
      exerciseLibrary: _library,
    );
    expect(plan.workouts, hasLength(3));
  });

  test('3 days/week -> full body split; 4 days -> upper/lower split', () {
    final threeDay = engine.generateWeek(
      profile: const TrainingProfile(fitnessLevel: FitnessLevel.beginner, availableEquipment: {}, daysPerWeek: 3, minutesPerSession: 30),
      exerciseLibrary: _library,
    );
    expect(threeDay.workouts.map((w) => w.workoutType), everyElement('strength_full_body'));

    final fourDay = engine.generateWeek(
      profile: const TrainingProfile(fitnessLevel: FitnessLevel.beginner, availableEquipment: {}, daysPerWeek: 4, minutesPerSession: 30),
      exerciseLibrary: _library,
    );
    expect(fourDay.workouts.map((w) => w.workoutType), ['strength_upper', 'strength_lower', 'strength_upper', 'strength_lower']);
  });

  test('5 days/week with a fat-loss goal swaps the last day for HIIT', () {
    final plan = engine.generateWeek(
      profile: const TrainingProfile(
        fitnessLevel: FitnessLevel.intermediate,
        availableEquipment: {},
        daysPerWeek: 5,
        minutesPerSession: 30,
        goals: {'fat_loss'},
      ),
      exerciseLibrary: _library,
    );
    expect(plan.workouts.last.workoutType, 'hiit');
  });

  test('never selects an exercise requiring equipment the user does not have', () {
    final plan = engine.generateWeek(
      profile: const TrainingProfile(
        fitnessLevel: FitnessLevel.advanced,
        availableEquipment: {}, // no equipment at all
        daysPerWeek: 3,
        minutesPerSession: 30,
      ),
      exerciseLibrary: _library,
    );
    for (final workout in plan.workouts) {
      for (final ex in workout.exercises) {
        final exercise = _library.firstWhere((e) => e.id == ex.exerciseId);
        expect(exercise.requiresNoEquipment, isTrue,
            reason: '${exercise.id} requires equipment but user has none');
      }
    }
  });

  test('owning a pull-up bar unlocks pull-up selection over the equipment-free fallback', () {
    final plan = engine.generateWeek(
      profile: const TrainingProfile(
        fitnessLevel: FitnessLevel.intermediate,
        availableEquipment: {'pull_up_bar'},
        daysPerWeek: 3,
        minutesPerSession: 30,
      ),
      exerciseLibrary: _library,
    );
    final allExerciseIds = plan.workouts.expand((w) => w.exercises).map((e) => e.exerciseId).toSet();
    expect(allExerciseIds, contains('pull-up'));
  });

  test('a beginner never gets an advanced-only exercise', () {
    final plan = engine.generateWeek(
      profile: const TrainingProfile(
        fitnessLevel: FitnessLevel.beginner,
        availableEquipment: {'barbell'},
        daysPerWeek: 3,
        minutesPerSession: 30,
      ),
      exerciseLibrary: _library,
    );
    final allExerciseIds = plan.workouts.expand((w) => w.exercises).map((e) => e.exerciseId).toSet();
    expect(allExerciseIds, isNot(contains('barbell-squat')));
    expect(allExerciseIds, isNot(contains('diamond-push-up')));
  });

  test('sets/reps scale up with fitness level', () {
    final beginnerPlan = engine.generateWeek(
      profile: const TrainingProfile(fitnessLevel: FitnessLevel.beginner, availableEquipment: {}, daysPerWeek: 3, minutesPerSession: 30),
      exerciseLibrary: _library,
    );
    final advancedPlan = engine.generateWeek(
      profile: const TrainingProfile(fitnessLevel: FitnessLevel.advanced, availableEquipment: {'barbell'}, daysPerWeek: 3, minutesPerSession: 30),
      exerciseLibrary: _library,
    );
    final beginnerSets = beginnerPlan.workouts.first.exercises.first.targetSets!;
    final advancedSets = advancedPlan.workouts.first.exercises.first.targetSets!;
    expect(advancedSets, greaterThan(beginnerSets));
  });

  test('HIIT workouts use duration targets, not rep targets', () {
    final plan = engine.generateWeek(
      profile: const TrainingProfile(
        fitnessLevel: FitnessLevel.intermediate,
        availableEquipment: {},
        daysPerWeek: 5,
        minutesPerSession: 30,
        goals: {'cardio'},
      ),
      exerciseLibrary: _library,
    );
    final hiitWorkout = plan.workouts.firstWhere((w) => w.workoutType == 'hiit');
    for (final ex in hiitWorkout.exercises) {
      expect(ex.targetDurationSeconds, isNotNull);
      expect(ex.targetReps, isNull);
    }
  });

  test('zero days per week produces an empty plan, not an error', () {
    final plan = engine.generateWeek(
      profile: const TrainingProfile(fitnessLevel: FitnessLevel.beginner, availableEquipment: {}, daysPerWeek: 0, minutesPerSession: 30),
      exerciseLibrary: _library,
    );
    expect(plan.workouts, isEmpty);
  });
}
