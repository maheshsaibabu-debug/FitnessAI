import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../connectivity/connectivity_monitor.dart';
import '../database/database_provider.dart';
import 'sync_engine.dart';
import 'sync_queue_repository.dart';

part 'sync_providers.g.dart';

@Riverpod(keepAlive: true)
SyncQueueRepository syncQueueRepository(Ref ref) {
  return SyncQueueRepository(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
SyncEngine syncEngine(Ref ref) {
  final engine = SyncEngine(ref.watch(syncQueueRepositoryProvider), Supabase.instance.client);

  // Drain whenever connectivity flips to online. This is the app's only
  // "automatic" sync trigger besides app-resume and the periodic timer
  // wired in main.dart — see docs/SYNC_ENGINE.md.
  ref.listen(connectivityStatusProvider, (previous, next) {
    final wasOffline = previous?.valueOrNull == false;
    final isOnline = next.valueOrNull == true;
    if (isOnline && (wasOffline || previous == null)) {
      engine.drainQueue();
    }
  });

  return engine;
}
