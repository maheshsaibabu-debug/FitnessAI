import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_monitor.g.dart';

/// The app's single notion of "online". Nothing in `domain/` or the core
/// local flows may gate on this — it exists purely to decide when the
/// SyncEngine should attempt to drain the outbox and when to show the
/// subtle offline indicator (see docs/OFFLINE_FIRST.md).
@Riverpod(keepAlive: true)
class ConnectivityStatus extends _$ConnectivityStatus {
  @override
  Stream<bool> build() {
    final connectivity = Connectivity();
    return connectivity.onConnectivityChanged.map(_isOnline).asyncMap((online) async {
      // Debounce a transient flap (e.g. wifi handoff) so the sync engine
      // doesn't thrash on/off within the same second.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return online;
    });
  }

  bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}

@riverpod
Future<bool> isCurrentlyOnline(Ref ref) async {
  final connectivity = Connectivity();
  final results = await connectivity.checkConnectivity();
  return results.any((r) => r != ConnectivityResult.none);
}
