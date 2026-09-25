import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';

const _uuid = Uuid();

const _mealSplit = {
  'breakfast': 0.25,
  'lunch': 0.35,
  'snack': 0.10,
  'dinner': 0.30,
};

/// One meal slot in today's diet chart, joined with the latest confirmation
/// (if any) of whether the user actually ate it.
class DietMeal {
  const DietMeal({required this.meal, this.latestLog});

  final Meal meal;
  final MealLog? latestLog;

  /// null = not yet answered, true = confirmed eaten, false = confirmed skipped.
  bool? get eaten => latestLog == null ? null : latestLog!.quantity > 0;
}

/// Builds today's diet chart from the user's stored calorie/macro targets
/// (see NutritionCalculationEngine) by splitting them across the standard
/// meal slots, and lets the user confirm — per meal — whether they actually
/// ate it. MealLogs stays the same append-only "what really happened"
/// event log every other tracked metric in this app uses.
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

    final now = DateTime.now().toUtc();
    final rows = _mealSplit.entries
        .map((entry) => MealsCompanion.insert(
              id: _uuid.v4(),
              userId: userId,
              date: today,
              mealType: entry.key,
              name: _titleCase(entry.key),
              calories: targets.calorieTarget * entry.value,
              proteinGrams: targets.proteinGrams * entry.value,
              carbsGrams: targets.carbsGrams * entry.value,
              fatGrams: targets.fatGrams * entry.value,
              createdAt: now,
            ))
        .toList();

    await _db.batch((batch) => batch.insertAll(_db.meals, rows));
    return (_db.select(_db.meals)..where((m) => m.userId.equals(userId) & m.date.equals(today))).get();
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
