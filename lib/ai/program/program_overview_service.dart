import '../ai_provider.dart' show AiProviderException;
import 'ai_program_overview_provider.dart';
import 'deterministic_program_overview_builder.dart';
import 'program_overview_input.dart';

/// AI-first, deterministic-fallback for the Program view's narrative —
/// the same pattern as Coach chat and plan generation, applied here too.
class ProgramOverviewService {
  ProgramOverviewService({required this.aiProvider});

  final AiProgramOverviewProvider aiProvider;
  static const _fallback = DeterministicProgramOverviewBuilder();

  Future<ProgramOverviewResult> generate(ProgramOverviewInput input) async {
    try {
      return await aiProvider.generate(input);
    } on AiProviderException {
      return _fallback.build(input);
    }
  }
}
