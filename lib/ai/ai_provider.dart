import 'fitness_context.dart';

/// A coaching reply — always natural language over numbers the
/// deterministic engines already computed, never a source of new plan or
/// nutrition numbers itself. See docs/AI_ARCHITECTURE.md.
class CoachResponse {
  const CoachResponse({required this.message, required this.source, this.model});

  final String message;

  /// 'cloud' or 'rule_based' — shown subtly in the UI so a fallback reply
  /// never masquerades as a live model response.
  final String source;

  /// The model the gateway actually used, as it reports it — never
  /// hard-coded client-side (docs/AI_ARCHITECTURE.md's provider
  /// abstraction). Null for rule-based replies.
  final String? model;
}

/// Thrown by any [AiProvider] that can't produce a reply right now
/// (offline, gateway error, timeout) — the coach feature catches this and
/// falls back to [RuleBasedFallbackProvider] rather than surfacing a bare
/// error to the user.
class AiProviderException implements Exception {
  AiProviderException(this.message, [this.cause]);
  final String message;
  final Object? cause;

  @override
  String toString() => 'AiProviderException: $message${cause != null ? ' ($cause)' : ''}';
}

/// docs/AI_ARCHITECTURE.md's provider abstraction. No implementation
/// outside `ai/providers/cloud_ai_provider.dart` may know a specific LLM
/// vendor's SDK or API shape.
abstract class AiProvider {
  Future<CoachResponse> respond(FitnessContext context, String userMessage);
}
