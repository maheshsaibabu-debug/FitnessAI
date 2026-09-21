import 'package:flutter_dotenv/flutter_dotenv.dart';

enum AppEnvironment { development, staging, production }

/// Typed access to `.env`. Load with `Env.load()` once in `main()` before
/// anything else reads a value.
class Env {
  Env._();

  static Future<void> load() => dotenv.load(fileName: '.env');

  static String get supabaseUrl => _require('SUPABASE_URL');
  static String get supabaseAnonKey => _require('SUPABASE_ANON_KEY');
  static String get aiGatewayFunctionName => _optional('AI_GATEWAY_FUNCTION_NAME') ?? 'ai-coach-gateway';
  static String get aiPlanGatewayFunctionName => _optional('AI_PLAN_GATEWAY_FUNCTION_NAME') ?? 'ai-plan-generator';
  static String get aiProgramOverviewFunctionName =>
      _optional('AI_PROGRAM_OVERVIEW_FUNCTION_NAME') ?? 'ai-program-overview';

  static AppEnvironment get appEnvironment {
    switch (dotenv.env['APP_ENV']) {
      case 'production':
        return AppEnvironment.production;
      case 'staging':
        return AppEnvironment.staging;
      default:
        return AppEnvironment.development;
    }
  }

  static String _require(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      throw StateError(
        'Missing required env var "$key". Copy .env.example to .env and fill it in.',
      );
    }
    return value;
  }

  /// Like [_require] but for a value that has a sensible fallback rather
  /// than being a launch requirement — never throws, including when
  /// `.env` was never loaded at all (e.g. a test that never calls
  /// [load]/`dotenv.testLoad`, because nothing it exercises has needed a
  /// config value before).
  static String? _optional(String key) {
    try {
      return dotenv.env[key];
    } catch (_) {
      return null;
    }
  }
}
