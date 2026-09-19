import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../ai/ai_provider.dart';
import '../../../ai/ai_providers.dart';

part 'coach_controller.g.dart';

class CoachMessage {
  const CoachMessage({required this.text, required this.isUser, this.source, this.model});

  final String text;
  final bool isUser;

  /// 'cloud' | 'rule_based' — null for the user's own messages.
  final String? source;
  final String? model;
}

/// Drives the Coach chat: resolves a bounded [FitnessContext], tries the
/// cloud gateway, and falls back to the rule-based provider on any
/// failure — docs/AI_ARCHITECTURE.md's fallback chain. Messages are kept
/// in memory only for now; there's no conversation-history table yet, so
/// nothing is silently invented to persist across app restarts.
@Riverpod(keepAlive: true)
class CoachController extends _$CoachController {
  @override
  List<CoachMessage> build() => const [];

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    state = [...state, CoachMessage(text: trimmed, isUser: true)];

    final context = await ref.read(fitnessContextResolverProvider).resolve();
    if (context == null) {
      state = [
        ...state,
        const CoachMessage(
          text: 'Finish setting up your profile first — once you have, I\'ll have something real to work with.',
          isUser: false,
          source: 'rule_based',
        ),
      ];
      return;
    }

    CoachResponse response;
    try {
      response = await ref.read(cloudAiProviderProvider).respond(context, trimmed);
    } on AiProviderException {
      response = await ref.read(ruleBasedFallbackProviderProvider).respond(context, trimmed);
    }

    state = [
      ...state,
      CoachMessage(text: response.message, isUser: false, source: response.source, model: response.model),
    ];
  }
}
