# AI Architecture

Status: designed, not yet implemented (`lib/ai/` is currently empty folders — implementation phase 11). This document is the contract that phase 11 implements against.

## Provider abstraction

```dart
abstract class AiProvider {
  Future<CoachResponse> respond(FitnessContext context, String userMessage);
}

class CloudAiProvider implements AiProvider { ... }        // Supabase Edge Function
class OnDeviceAiProvider implements AiProvider { ... }      // optional, future, capability-gated
class RuleBasedFallbackProvider implements AiProvider { ... } // pure Dart, always available
```

No class in `lib/` outside `ai/providers/cloud_ai_provider.dart` may reference a specific LLM vendor's SDK or API shape — the vendor lives behind the Edge Function, swappable server-side without a client release.

## Division of responsibility

**Never delegated to the LLM** (these are deterministic and live in `domain/`, testable with plain unit tests, no network): set/rep progression math, streak counting, PR detection, nutrition target calculation, adaptive-plan rule application, all database consistency. See the engines listed in [ARCHITECTURE.md](ARCHITECTURE.md) §7.

**LLM's job**: natural-language coaching, motivational copy, explaining *why* a plan changed in plain language, conversational Q&A, meal-alternative suggestions, interpreting a progress trend in words. Pure language generation over numbers the deterministic engines already computed.

## FitnessContextResolver

Assembles a bounded context object before any cloud call — never raw historical rows:

```
profile + goal + baseline
+ recent workout summary (adherence %, last N sessions' outcome, not every set)
+ step trend (7/30-day average, not daily raw)
+ weight trend (direction + rate, not every log entry)
+ nutrition adherence %
+ recovery signal (today's check-in only)
+ explicit user preferences
```

Older history is summarized into these trend/adherence numbers rather than sent verbatim, keeping token spend predictable regardless of how long the user has used the app.

## Fallback behavior

```
CloudAiProvider.respond() throws AiProviderException
  -> caught by the coach feature's repository
  -> RuleBasedFallbackProvider.respond() — wraps domain/motivation_engine.dart
  -> user sees a real, useful message (e.g. "Your coach is offline right now, but your next workout is ready.")
```

Never a bare "AI unavailable, try again later" as the only outcome — that violates the product brief §15.

## Observability (phase 11)

Every call records: provider, model (as reported by the gateway, not hard-coded client-side), request type, latency, success/failure, token usage if available, cache status. Never the raw user message or raw context payload — see [PRIVACY.md](PRIVACY.md).
