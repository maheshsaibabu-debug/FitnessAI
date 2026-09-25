import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/nutrition_repository.dart';
import '../../../data/repositories/repository_providers.dart';
import '../application/diet_provider.dart';

const _mealTypeOrder = ['breakfast', 'lunch', 'snack', 'dinner'];

/// Today's diet chart: calorie/macro targets split across the standard
/// meal slots (see NutritionRepository), with a per-meal "did you have
/// this?" confirmation so the app has a real record of adherence, not
/// just a plan.
class DietScreen extends ConsumerWidget {
  const DietScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diet = ref.watch(todaysDietProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Diet')),
      body: SafeArea(
        child: diet.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(
            child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load your diet chart: $e')),
          ),
          data: (meals) {
            if (meals.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Finish onboarding to get your daily calorie and macro targets first.'),
                ),
              );
            }
            final sorted = [...meals]
              ..sort((a, b) =>
                  _mealTypeOrder.indexOf(a.meal.mealType).compareTo(_mealTypeOrder.indexOf(b.meal.mealType)));
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text("Today's diet chart", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'Based on your calorie and macro targets',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                for (final dietMeal in sorted) _DietMealCard(dietMeal: dietMeal),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DietMealCard extends ConsumerWidget {
  const _DietMealCard({required this.dietMeal});

  final DietMeal dietMeal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final meal = dietMeal.meal;
    final eaten = dietMeal.eaten;

    Future<void> confirm(bool ate) async {
      await ref.read(nutritionRepositoryProvider).confirmMeal(meal: meal, userId: meal.userId, eaten: ate);
      ref.invalidate(todaysDietProvider);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(meal.name, style: Theme.of(context).textTheme.titleMedium)),
                Text('${meal.calories.round()} kcal', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Protein ${meal.proteinGrams.round()}g · Carbs ${meal.carbsGrams.round()}g · Fat ${meal.fatGrams.round()}g',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            for (final item in dietMeal.items) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${item.quantity}× ', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: Theme.of(context).textTheme.bodyMedium),
                        Text(
                          '${item.calories.round()} kcal · P ${item.proteinGrams.round()}g · C ${item.carbsGrams.round()}g · F ${item.fatGrams.round()}g',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text('Did you have this?', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: eaten == true
                      ? FilledButton(onPressed: () => confirm(true), child: const Text('Yes'))
                      : OutlinedButton(onPressed: () => confirm(true), child: const Text('Yes')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: eaten == false
                      ? FilledButton.tonal(onPressed: () => confirm(false), child: const Text('No'))
                      : OutlinedButton(onPressed: () => confirm(false), child: const Text('No')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
