import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:fitness_companion/core/database/app_database.dart';
import 'package:fitness_companion/data/repositories/nutrition_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late NutritionRepository repository;
  const userId = 'test-user';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = NutritionRepository(db);

    final now = DateTime.now().toUtc();
    await db
        .into(db.userProfiles)
        .insert(
          UserProfilesCompanion.insert(
            id: userId,
            name: 'Test User',
            sex: 'male',
            dietaryPreference: const Value('omnivore'),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.nutritionGoals)
        .insert(
          NutritionGoalsCompanion.insert(
            id: 'goal-1',
            userId: userId,
            calorieTarget: 2000,
            proteinGrams: 150,
            carbsGrams: 200,
            fatGrams: 65,
            calculationMethod: 'mifflin_st_jeor',
            updatedAt: now,
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  test('generates today\'s diet on first read', () async {
    final meals = await repository.todaysDiet(userId);
    expect(meals, isNotEmpty);
    expect(meals.every((m) => m.items.isNotEmpty), isTrue);
  });

  test(
    'regenerating with no confirmations swaps in a fresh set of meals',
    () async {
      await repository.todaysDiet(userId);
      final before = await (db.select(
        db.meals,
      )..where((m) => m.userId.equals(userId))).get();

      final result = await repository.regenerateTodaysDiet(userId);

      expect(result, RegenerateDietResult.success);
      final after = await (db.select(
        db.meals,
      )..where((m) => m.userId.equals(userId))).get();
      expect(after.length, before.length);
      expect(after.every((m) => before.every((b) => b.id != m.id)), isTrue);
    },
  );

  test('regenerate is blocked once a meal has been confirmed today', () async {
    final meals = await repository.todaysDiet(userId);
    await repository.confirmMeal(
      meal: meals.first.meal,
      userId: userId,
      eaten: true,
    );

    final result = await repository.regenerateTodaysDiet(userId);

    expect(result, RegenerateDietResult.blockedByExistingLogs);
    final unchanged = await (db.select(
      db.meals,
    )..where((m) => m.userId.equals(userId))).get();
    expect(
      unchanged.map((m) => m.id).toSet(),
      meals.map((m) => m.meal.id).toSet(),
    );
  });

  test(
    'regenerate reports noTargetsYet when the user has no nutrition goals',
    () async {
      const otherUser = 'no-targets-user';
      final result = await repository.regenerateTodaysDiet(otherUser);
      expect(result, RegenerateDietResult.noTargetsYet);
    },
  );
}
