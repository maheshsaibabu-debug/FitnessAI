import 'package:flutter_dotenv/flutter_dotenv.dart';

enum AppEnvironment { development, staging, production }

/// Typed access to `.env`. Load with `Env.load()` once in `main()` before
/// anything else reads a value.
class Env {
  Env._();

  static Future<void> load() => dotenv.load(fileName: '.env');

  static String get supabaseUrl => _require('SUPABASE_URL');
  static String get supabaseAnonKey => _require('SUPABASE_ANON_KEY');
  static String get aiGatewayFunctionName =>
      dotenv.env['AI_GATEWAY_FUNCTION_NAME'] ?? 'ai-coach-gateway';

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
}
