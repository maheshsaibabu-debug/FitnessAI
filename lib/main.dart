import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/sync/sync_providers.dart';

final _log = Logger('main');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((r) => debugPrint('[${r.level.name}] ${r.loggerName}: ${r.message}'));

  await Env.load();

  // Supabase is an enhancement, never a launch requirement (docs/OFFLINE_FIRST.md
  // "the app must never depend on the internet for core fitness functionality").
  // A missing/unreachable project must not prevent the app from starting.
  var supabaseReady = false;
  try {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );
    supabaseReady = true;
  } catch (e, st) {
    _log.warning('Supabase init failed — continuing in offline-only mode', e, st);
  }

  final container = ProviderContainer();
  if (supabaseReady) {
    // Instantiating (not just defining) the provider starts its
    // connectivity listener, so the outbox drains automatically once the
    // device comes online — see docs/SYNC_ENGINE.md.
    container.read(syncEngineProvider);
  }

  runApp(UncontrolledProviderScope(container: container, child: const FitnessCompanionApp()));
}
