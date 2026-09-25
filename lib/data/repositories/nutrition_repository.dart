import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../domain/nutrition_engine/nutrition_calculation_engine.dart';
import '../../domain/progress_engine/progress_analysis_engine.dart';

const _uuid = Uuid();

const _mealSplit = {
  'breakfast': 0.25,
  'lunch': 0.35,
  'snack': 0.10,
  'dinner': 0.30,
};

/// Per-serving macros for a small set of concrete dishes per meal slot —
/// just enough to make the diet chart a real "here's what to eat" view
/// (salad, paneer chicken, ...) rather than a bare macro total. Not a
/// food database (see the Foods table's own doc comment); portions are
/// scaled to the day's target, not looked up.
class _FoodTemplate {
  const _FoodTemplate(this.name, this.calories, this.protein, this.carbs, this.fat);
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
}

const _mealTemplates = <String, List<_FoodTemplate>>{
  'breakfast': [
    _FoodTemplate('Oats porridge', 150, 5, 27, 3),
    _FoodTemplate('Boiled eggs', 78, 6, 0.6, 5),
  ],
  'lunch': [
    _FoodTemplate('Grilled chicken breast', 165, 31, 0, 3.6),
    _FoodTemplate('Brown rice', 216, 5, 45, 1.8),
    _FoodTemplate('Salad', 35, 2, 6, 0.3),
  ],
  'snack': [
    _FoodTemplate('Mixed nuts', 170, 6, 6, 15),
    _FoodTemplate('Fruit bowl', 80, 1, 20, 0.3),
  ],
  'dinner': [
    _FoodTemplate('Paneer chicken curry', 250, 22, 8, 15),
    _FoodTemplate('Salad', 35, 2, 6, 0.3),
  ],
};

/// One concrete food item within a meal, with a portion scaled to fit
/// that meal's calorie share of the day's target.
class DietItem {
  const DietItem({
    required this.name,
    required this.quantity,
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
  });

  final String name;
  final double quantity; // servings
  final double calories;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;

  Map<String, Object?> toJson() => {
        'name': name,
        'quantity': quantity,
        'calories': calories,
        'proteinGrams': proteinGrams,
        'carbsGrams': carbsGrams,
        'fatGrams': fatGrams,
      };

  factory DietItem.fromJson(Map<String, Object?> json) => DietItem(
        name: json['name'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        calories: (json['calories'] as num).toDouble(),
        proteinGrams: (json['proteinGrams'] as num).toDouble(),
        carbsGrams: (json['carbsGrams'] as num).toDouble(),
        fatGrams: (json['fatGrams'] as num).toDouble(),
      );
}

/// One meal slot in today's diet chart, joined with the latest confirmation
/// (if any) of whether the user actually ate it.
class DietMeal {
  const DietMeal({required this.meal, this.latestLog});

  final Meal meal;
  final MealLog? latestLog;

  /// null = not yet answered, true = confirmed eaten, false = confirmed skipped.
  bool? get eaten => latestLog == null ? null : latestLog!.quantity > 0;

  List<DietItem> get items {
    final decoded = jsonDecode(meal.ingredientsJson) as List;
    return decoded.map((e) => DietItem.fromJson(e as Map<String, Object?>)).toList();
  }
}

/// Builds today's diet chart from the user's stored calorie/macro targets
/// (see NutritionCalculationEngine), nudged by their real weight-log
/// trend (see NutritionCalculationEngine.adjustForProgress), split across
/// the standard meal slots as concrete food items. Lets the user confirm
/// — per meal — whether they actually ate it. MealLogs stays the same
/// append-only "what really happened" event log every other tracked
/// metric in this app uses.
class NutritionRepository {
  NutritionRepository(this._db);

  final AppDatabase _db;

  Future<List<DietMeal>> todaysDiet(String userId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    var meals =
        await (_db.select(_db.meals)..where((m) => m.userId.equals(userId) & m.date.equals(today))).get();
    if (meals.isEmpty) {
      meals = await _generateTodaysMeals(userId, today);
    }
    if (meals.isEmpty) return const []; // no nutrition targets yet — nothing to chart

    final logs =
        await (_db.select(_db.mealLogs)..where((l) => l.userId.equals(userId) & l.date.equals(today))).get();

    return meals.map((meal) {
      final mealLogs = logs.where((l) => l.mealId == meal.id).toList()
        ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
      return DietMeal(meal: meal, latestLog: mealLogs.isEmpty ? null : mealLogs.last);
    }).toList();
  }

  Future<List<Meal>> _generateTodaysMeals(String userId, DateTime today) async {
    final targets =
        await (_db.select(_db.nutritionGoals)..where((g) => g.userId.equals(userId))).getSingleOrNull();
    if (targets == null) return const [];

    final calorieTarget = await _progressAdjustedCalorieTarget(userId, targets.calorieTarget);

    final now = DateTime.now().toUtc();
    final rows = _mealSplit.entries.map((entry) {
      final items = _scaledItems(entry.key, calorieTarget * entry.value);
      return MealsCompanion.insert(
        id: _uuid.v4(),
        userId: userId,
        date: today,
        mealType: entry.key,
        name: _titleCase(entry.key),
        ingredientsJson: Value(jsonEncode(items.map((i) => i.toJson()).toList())),
        calories: items.fold(0.0, (sum, i) => sum + i.calories),
        proteinGrams: items.fold(0.0, (sum, i) => sum + i.proteinGrams),
        carbsGrams: items.fold(0.0, (sum, i) => sum + i.carbsGrams),
        fatGrams: items.fold(0.0, (sum, i) => sum + i.fatGrams),
        createdAt: now,
      );
    }).toList();

    await _db.batch((batch) => batch.insertAll(_db.meals, rows));
    return (_db.select(_db.meals)..where((m) => m.userId.equals(userId) & m.date.equals(today))).get();
  }

  /// Reads the user's real weight-log trend and primary goal, and nudges
  /// the stored calorie target toward what that trend implies is needed —
  /// "based on progress", not just a number frozen at onboarding.
  Future<int> _progressAdjustedCalorieTarget(String userId, int baseCalorieTarget) async {
    final goalRow = await (_db.select(_db.fitnessGoals)
          ..where((g) => g.userId.equals(userId) & g.isPrimary.equals(true))
          ..limit(1))
        .getSingleOrNull();
    final goal = _toNutritionGoalType(goalRow?.goalType);

    final since = DateTime.now().subtract(const Duration(days: 21));
    final weightRows = await (_db.select(_db.weightLogs)
          ..where((w) => w.userId.equals(userId) & w.recordedAt.isBiggerOrEqualValue(since))
          ..orderBy([(w) => OrderingTerm.asc(w.recordedAt)]))
        .get();
    final samples = weightRows.map((w) => WeightSample(w.recordedAt, w.weightKg)).toList();
    final trend = const ProgressAnalysisEngine().weightTrend(samples);

    return const NutritionCalculationEngine().adjustForProgress(
      baseCalorieTarget: baseCalorieTarget,
      goal: goal,
      actualWeeklyRateKg: trend?.ratePerWeek,
    );
  }

  NutritionGoalType _toNutritionGoalType(String? goal) => switch (goal) {
        'fat_loss' => NutritionGoalType.fatLoss,
        'muscle_gain' => NutritionGoalType.muscleGain,
        'weight_gain' => NutritionGoalType.weightGain,
        _ => NutritionGoalType.maintain,
      };

  List<DietItem> _scaledItems(String mealType, double targetCalories) {
    final templates = _mealTemplates[mealType] ?? const [];
    if (templates.isEmpty) return const [];
    final baseTotal = templates.fold(0.0, (sum, t) => sum + t.calories);
    final multiplier = double.parse((targetCalories / baseTotal).clamp(0.5, 3.0).toStringAsFixed(1));

    return templates
        .map((t) => DietItem(
              name: t.name,
              quantity: multiplier,
              calories: double.parse((t.calories * multiplier).toStringAsFixed(0)),
              proteinGrams: double.parse((t.protein * multiplier).toStringAsFixed(1)),
              carbsGrams: double.parse((t.carbs * multiplier).toStringAsFixed(1)),
              fatGrams: double.parse((t.fat * multiplier).toStringAsFixed(1)),
            ))
        .toList();
  }

  /// Always appends a new event rather than mutating a prior answer — the
  /// UI reads the latest entry per meal as the current answer.
  Future<void> confirmMeal({required Meal meal, required String userId, required bool eaten}) {
    return _db.into(_db.mealLogs).insert(MealLogsCompanion.insert(
          id: _uuid.v4(),
          userId: userId,
          mealId: Value(meal.id),
          date: meal.date,
          mealType: meal.mealType,
          quantity: Value(eaten ? 1.0 : 0.0),
          calories: eaten ? meal.calories : 0,
          proteinGrams: eaten ? meal.proteinGrams : 0,
          carbsGrams: eaten ? meal.carbsGrams : 0,
          fatGrams: eaten ? meal.fatGrams : 0,
          eventId: _uuid.v4(),
          loggedAt: DateTime.now().toUtc(),
        ));
  }

  String _titleCase(String s) => '${s[0].toUpperCase()}${s.substring(1)}';
}
