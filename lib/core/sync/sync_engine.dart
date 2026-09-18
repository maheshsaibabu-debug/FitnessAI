import 'dart:convert';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';
import 'sync_event_type.dart';
import 'sync_queue_repository.dart';

final _log = Logger('SyncEngine');

/// Drains the local outbox against Supabase. Never called from the UI
/// build path — it runs in the background, triggered by connectivity
/// regained, app resume, and a periodic timer (wired up where the app's
/// providers are composed). See docs/SYNC_ENGINE.md.
class SyncEngine {
  SyncEngine(this._queue, this._client);

  final SyncQueueRepository _queue;
  final SupabaseClient _client;

  static const _maxAttempts = 8;

  bool _running = false;

  /// Drains everything currently pending. Safe to call repeatedly/
  /// concurrently — re-entrant calls no-op while a drain is already
  /// in-flight.
  Future<void> drainQueue() async {
    if (_running) return;
    _running = true;
    try {
      await _queue.recoverInterrupted();
      while (true) {
        final batch = await _queue.pending();
        if (batch.isEmpty) break;

        for (final entry in batch) {
          if (entry.attemptCount >= _maxAttempts) {
            _log.warning('Giving up on sync entry ${entry.id} after $_maxAttempts attempts');
            continue;
          }
          await _uploadOne(entry);
        }

        // If nothing in this batch actually completed (all still
        // pending/failed), stop to avoid a tight retry loop; the periodic
        // trigger will try again later with backoff already recorded.
        final stillPending = await _queue.pending(limit: 1);
        if (stillPending.isNotEmpty && stillPending.first.id == batch.first.id) break;
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _uploadOne(SyncQueueEntry entry) async {
    final backoff = _backoffFor(entry.attemptCount);
    if (entry.lastAttemptAt != null &&
        DateTime.now().toUtc().difference(entry.lastAttemptAt!) < backoff) {
      return; // not due for retry yet
    }

    await _queue.markInFlight(entry.id);
    try {
      final mapping = syncTableMappings[entry.entityType];
      if (mapping == null) {
        throw StateError('No sync mapping registered for "${entry.entityType}"');
      }

      final payload = jsonDecode(entry.payloadJson) as Map<String, Object?>;

      switch (entry.operation) {
        case 'delete':
          await _client
              .from(mapping.table)
              .delete()
              .eq(mapping.conflictColumn, payload[mapping.conflictColumn] as Object);
        default:
          await _client.from(mapping.table).upsert(
                payload,
                onConflict: mapping.conflictColumn,
                ignoreDuplicates: mapping.ignoreDuplicates,
              );
      }

      await _queue.markDone(entry.id);
    } catch (e) {
      _log.warning('Sync upload failed for ${entry.entityType}/${entry.id}: $e');
      await _queue.markFailed(entry.id, e.toString());
    }
  }

  Duration _backoffFor(int attemptCount) {
    final seconds = min(pow(2, attemptCount).toInt(), 300); // cap at 5 min
    return Duration(seconds: seconds);
  }
}
