import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/config/env.dart';
import '../data/repositories/repository_providers.dart';
import 'ai_provider.dart';
import 'fitness_context_resolver.dart';
import 'providers/cloud_ai_provider.dart';
import 'providers/rule_based_fallback_provider.dart';

part 'ai_providers.g.dart';

@Riverpod(keepAlive: true)
FitnessContextResolver fitnessContextResolver(Ref ref) {
  return FitnessContextResolver(
    profileRepository: ref.watch(profileRepositoryProvider),
    workoutPlanRepository: ref.watch(workoutPlanRepositoryProvider),
    stepsRepository: ref.watch(stepsRepositoryProvider),
    weightRepository: ref.watch(weightRepositoryProvider),
  );
}

@Riverpod(keepAlive: true)
AiProvider cloudAiProvider(Ref ref) => CloudAiProvider(functionName: Env.aiGatewayFunctionName);

@Riverpod(keepAlive: true)
AiProvider ruleBasedFallbackProvider(Ref ref) => const RuleBasedFallbackProvider();
