import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/database/app_database.dart';
import '../../domain/workout_engine/exercise_summary.dart';

/// Loads the bundled exercise library (assets/data/exercises.json) into
/// the local database on first run. Idempotent — safe to call on every
/// app start, it only writes when the table is actually empty. This is
/// what makes "exercise library implemented" mean "works with zero
/// network access" rather than "downloads on first launch."
class ExerciseLibrarySeeder {
  ExerciseLibrarySeeder(this._db);

  final AppDatabase _db;

  Future<void> seedIfEmpty() async {
    final alreadySeeded = await (_db.select(_db.exercises)..limit(1)).get();
    if (alreadySeeded.isNotEmpty) return;

    final raw = await rootBundle.loadString('assets/data/exercises.json');
    final entries = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();

    await _db.batch((batch) {
      batch.insertAll(
        _db.exercises,
        entries.map((e) => ExercisesCompanion.insert(
              id: e['id'] as String,
              name: e['name'] as String,
              category: e['category'] as String,
              difficulty: e['difficulty'] as String,
              instructions: e['instructions'] as String,
              primaryMusclesJson: Value(jsonEncode(e['primaryMuscles'] ?? const [])),
              secondaryMusclesJson: Value(jsonEncode(e['secondaryMuscles'] ?? const [])),
              equipmentJson: Value(jsonEncode(e['equipment'] ?? const [])),
              formCuesJson: Value(jsonEncode(e['formCues'] ?? const [])),
              commonMistakesJson: Value(jsonEncode(e['commonMistakes'] ?? const [])),
              beginnerVariantId: Value(e['regression'] as String?),
              advancedVariantId: Value(e['progression'] as String?),
            )),
      );
    });
  }

  Future<List<ExerciseSummary>> loadSummaries() async {
    final rows = await _db.select(_db.exercises).get();
    return rows
        .map((r) => ExerciseSummary(
              id: r.id,
              name: r.name,
              category: r.category,
              primaryMuscles: (jsonDecode(r.primaryMusclesJson) as List).cast<String>(),
              equipment: (jsonDecode(r.equipmentJson) as List).cast<String>(),
              difficulty: r.difficulty,
            ))
        .toList();
  }
}
