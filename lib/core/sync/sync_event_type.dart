/// Every kind of local mutation that gets enqueued to the outbox. Kept as
/// a closed enum (rather than a free-form string at call sites) so a typo
/// in an entity name fails at compile time, not silently at sync time.
enum SyncEventType {
  workoutStarted,
  setCompleted,
  workoutCompleted,
  workoutSkipped,
  stepsUpdated,
  weightLogged,
  bodyMetricLogged,
  mealLogged,
  taskCompleted,
  taskSkipped,
  checkinCompleted,
  prRecorded,
  profileUpdated,
  planCreated,
  challengeJoined,
}

/// Maps a sync event to the Supabase table it upserts into and how
/// duplicate `event_id`s should be treated. Append-only event tables
/// ignore duplicates (idempotent no-op); mutable singletons upsert by
/// their own primary key instead of `event_id` — see
/// docs/SYNC_CONFLICTS.md.
class SyncTableMapping {
  const SyncTableMapping({
    required this.table,
    required this.conflictColumn,
    required this.ignoreDuplicates,
  });

  final String table;
  final String conflictColumn;
  final bool ignoreDuplicates;
}

const Map<String, SyncTableMapping> syncTableMappings = {
  'workout_completion': SyncTableMapping(
    table: 'workout_completions',
    conflictColumn: 'event_id',
    ignoreDuplicates: true,
  ),
  'workout_set': SyncTableMapping(
    table: 'workout_sets',
    conflictColumn: 'event_id',
    ignoreDuplicates: true,
  ),
  'exercise_progression': SyncTableMapping(
    table: 'exercise_progressions',
    conflictColumn: 'event_id',
    ignoreDuplicates: true,
  ),
  'step_record': SyncTableMapping(
    table: 'step_records',
    conflictColumn: 'id',
    ignoreDuplicates: false, // daily total: upsert, not append
  ),
  'weight_log': SyncTableMapping(
    table: 'weight_logs',
    conflictColumn: 'event_id',
    ignoreDuplicates: true,
  ),
  'body_composition_log': SyncTableMapping(
    table: 'body_composition_logs',
    conflictColumn: 'event_id',
    ignoreDuplicates: true,
  ),
  'measurement_log': SyncTableMapping(
    table: 'measurement_logs',
    conflictColumn: 'event_id',
    ignoreDuplicates: true,
  ),
  'meal_log': SyncTableMapping(
    table: 'meal_logs',
    conflictColumn: 'event_id',
    ignoreDuplicates: true,
  ),
  'task_completion': SyncTableMapping(
    table: 'task_completions',
    conflictColumn: 'event_id',
    ignoreDuplicates: true,
  ),
  'personal_record': SyncTableMapping(
    table: 'personal_records',
    conflictColumn: 'event_id',
    ignoreDuplicates: true,
  ),
  'user_profile': SyncTableMapping(
    table: 'user_profiles',
    conflictColumn: 'id',
    ignoreDuplicates: false, // mutable singleton: last-write-wins by version
  ),
  'workout_plan': SyncTableMapping(
    table: 'workout_plans',
    conflictColumn: 'id',
    ignoreDuplicates: false,
  ),
  'challenge_participation': SyncTableMapping(
    table: 'challenge_participations',
    conflictColumn: 'id',
    ignoreDuplicates: false,
  ),
};
