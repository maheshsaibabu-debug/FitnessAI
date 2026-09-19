import 'package:supabase_flutter/supabase_flutter.dart';

import '../ai_provider.dart';
import '../fitness_context.dart';

/// docs/AI_ARCHITECTURE.md's CloudAiProvider — the one place in `lib/`
/// allowed to know it's calling a Supabase Edge Function. The function
/// itself (supabase/functions/ai-coach-gateway) holds the real OpenRouter
/// key server-side and picks the model; this class never sees either.
class CloudAiProvider implements AiProvider {
  CloudAiProvider({required this.functionName});

  final String functionName;

  @override
  Future<CoachResponse> respond(FitnessContext context, String userMessage) async {
    final FunctionResponse response;
    try {
      response = await Supabase.instance.client.functions.invoke(
        functionName,
        body: {
          'userMessage': userMessage,
          'context': context.toJson(),
        },
      );
    } catch (e) {
      // Covers "Supabase never initialized" (offline-only launch, see
      // main.dart), network failure, and timeouts alike — the caller
      // doesn't need to distinguish, it just falls back.
      throw AiProviderException('Could not reach the coach gateway', e);
    }

    if (response.status != 200) {
      throw AiProviderException('Coach gateway returned status ${response.status}');
    }

    final data = response.data;
    if (data is! Map || data['message'] is! String) {
      throw AiProviderException('Coach gateway returned an unexpected response shape');
    }

    return CoachResponse(
      message: data['message'] as String,
      source: 'cloud',
      model: data['model'] as String?,
    );
  }
}
