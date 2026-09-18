import 'package:drift/drift.dart';

class NutritionGoals extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  IntColumn get calorieTarget => integer()();
  RealColumn get proteinGrams => real()();
  RealColumn get carbsGrams => real()();
  RealColumn get fatGrams => real()();
  TextColumn get calculationMethod => text()(); // e.g. mifflin_st_jeor
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Reference food data. Small bundled seed set for offline meal logging;
/// intentionally not a full food database (out of scope for local bundling).
class Foods extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get brand => text().nullable()();
  RealColumn get calories => real()();
  RealColumn get proteinGrams => real()();
  RealColumn get carbsGrams => real()();
  RealColumn get fatGrams => real()();
  TextColumn get servingUnit => text()();
  RealColumn get servingSize => real()();
  BoolColumn get isBundled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// A planned meal suggestion (from the meal-plan generator).
class Meals extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get mealType => text()(); // breakfast|lunch|snack|dinner
  TextColumn get name => text()();
  TextColumn get ingredientsJson => text().withDefault(const Constant('[]'))();
  RealColumn get calories => real()();
  RealColumn get proteinGrams => real()();
  RealColumn get carbsGrams => real()();
  RealColumn get fatGrams => real()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// What the user actually logged as eaten — an append-only event.
class MealLogs extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get mealId => text().nullable()();
  TextColumn get foodId => text().nullable()();
  DateTimeColumn get date => dateTime()();
  TextColumn get mealType => text()();
  RealColumn get quantity => real().withDefault(const Constant(1))();
  RealColumn get calories => real()();
  RealColumn get proteinGrams => real()();
  RealColumn get carbsGrams => real()();
  RealColumn get fatGrams => real()();
  TextColumn get eventId => text()();
  DateTimeColumn get loggedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
