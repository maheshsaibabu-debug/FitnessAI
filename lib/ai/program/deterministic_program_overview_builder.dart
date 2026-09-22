import 'program_overview_input.dart';

/// The offline fallback for the Program view — pure text, no network,
/// built from exactly the same real numbers the AI path would have
/// narrated. Plainer prose, same facts, same section structure:
/// docs/AI_ARCHITECTURE.md's rule that a failed cloud call must still
/// produce something real and useful, never a bare error — including
/// real (if generic) meal suggestions, not just "eat protein."
class DeterministicProgramOverviewBuilder {
  const DeterministicProgramOverviewBuilder();

  static const Map<String, List<(String label, String suggestion)>> _mealsByDiet = {
    'vegetarian': [
      ('Breakfast', 'Greek yogurt with berries and a handful of nuts, or eggs on whole-grain toast.'),
      ('Lunch', 'Paneer or tofu with rice or roti, dal, and a big portion of vegetables.'),
      ('Snack', 'Cottage cheese or a protein shake with a piece of fruit.'),
      ('Dinner', 'Tofu or beans with a whole grain and a large salad.'),
      ('Pre/post-workout', 'A banana with a scoop of whey or plant protein.'),
    ],
    'vegan': [
      ('Breakfast', 'Oats with plant milk, a scoop of plant protein, and berries.'),
      ('Lunch', 'Tofu, tempeh, or chickpeas with rice and roasted vegetables.'),
      ('Snack', 'Hummus with vegetables, or a handful of nuts and fruit.'),
      ('Dinner', 'Lentils or beans with a whole grain and a large salad.'),
      ('Pre/post-workout', 'A banana with a plant-protein shake.'),
    ],
    'pescatarian': [
      ('Breakfast', 'Eggs or Greek yogurt with fruit and a handful of nuts.'),
      ('Lunch', 'Grilled fish or shrimp with rice and vegetables.'),
      ('Snack', 'Greek yogurt or a protein shake with a piece of fruit.'),
      ('Dinner', 'Salmon or white fish with a whole grain and a large salad.'),
      ('Pre/post-workout', 'A banana with a scoop of whey protein.'),
    ],
    'omnivore': [
      ('Breakfast', 'Eggs with whole-grain toast, or Greek yogurt with fruit and nuts.'),
      ('Lunch', 'Chicken, beef, or fish with rice or potatoes and vegetables.'),
      ('Snack', 'Cottage cheese or a protein shake with a piece of fruit.'),
      ('Dinner', 'Lean meat or fish with a whole grain and a large salad.'),
      ('Pre/post-workout', 'A banana with a scoop of whey protein.'),
    ],
  };

  ProgramOverviewResult build(ProgramOverviewInput input) {
    final t = input.trajectory;

    final summary = StringBuffer('Hi ${input.name}. Here is your program, built from your real numbers.');
    if (t.wasAdjusted && t.adjustmentReason != null) {
      summary.write(' ${t.adjustmentReason}');
    }

    final weeklyPlanNarrative = input.weeklyPlan.isEmpty
        ? 'No workouts are scheduled yet — complete onboarding or regenerate your plan on the Plan tab.'
        : input.weeklyPlan.map((d) => '${d.title}: ${d.exerciseNames.join(', ')}').join('\n');

    final nutritionSummary = 'Your daily target is ${input.nutrition.calorieTarget} kcal, '
        '${input.nutrition.proteinGrams.toStringAsFixed(0)}g protein, '
        '${input.nutrition.carbsGrams.toStringAsFixed(0)}g carbs, and '
        '${input.nutrition.fatGrams.toStringAsFixed(0)}g fat. Hitting protein consistently matters more than '
        'hitting every number exactly.';

    final dietKey = input.dietaryPreference?.toLowerCase();
    final mealPairs = _mealsByDiet[dietKey] ?? _mealsByDiet['omnivore']!;
    final meals = mealPairs.map((m) => MealSuggestion(label: m.$1, suggestion: m.$2)).toList();

    return ProgramOverviewResult(
      summary: summary.toString(),
      weeklyPlanNarrative: weeklyPlanNarrative,
      nutritionSummary: nutritionSummary,
      meals: meals,
      trackingChecklist: const ['Weight trend (7-day average)', 'Steps', 'Workouts completed', 'Sleep'],
      closingLine: 'Consistency over the next few weeks matters more than any single day.',
      source: 'deterministic',
    );
  }
}
