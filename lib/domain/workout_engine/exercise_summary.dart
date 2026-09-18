/// The slice of an exercise's data the generation engine needs to make a
/// selection decision. Deliberately not a Drift row — the domain layer
/// has no dependency on the database or Flutter, so it stays trivially
/// unit-testable and reusable if the persistence layer ever changes.
class ExerciseSummary {
  const ExerciseSummary({
    required this.id,
    required this.name,
    required this.category,
    required this.primaryMuscles,
    required this.equipment,
    required this.difficulty,
  });

  final String id;
  final String name;

  /// strength | bodyweight | hiit | cardio | mobility | core
  final String category;
  final List<String> primaryMuscles;

  /// e.g. ['none'], ['dumbbells'], ['pull_up_bar']. 'none' means bodyweight
  /// only — always available regardless of what the user owns.
  final List<String> equipment;

  /// beginner | intermediate | advanced
  final String difficulty;

  bool get requiresNoEquipment => equipment.isEmpty || equipment.every((e) => e == 'none');
}
