-- Fitness Companion — initial schema
-- Mirrors lib/core/database/tables/*.dart. Every user-owned table is
-- scoped by RLS to auth.uid(). See docs/DATABASE.md and
-- docs/SYNC_CONFLICTS.md for the merge policy behind each table shape.

create extension if not exists "pgcrypto";

-- ============================================================
-- Profile
-- ============================================================

create table public.user_profiles (
  id uuid primary key,
  auth_user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  sex text not null,
  date_of_birth date,
  height_cm real,
  training_location text,
  equipment_json jsonb not null default '[]',
  fitness_level text,
  availability_days_per_week int,
  availability_minutes_per_session int,
  preferred_time_of_day text,
  dietary_preference text,
  dietary_restrictions_json jsonb not null default '[]',
  onboarding_completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version int not null default 1,
  unique (auth_user_id)
);

create table public.fitness_goals (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  goal_type text not null,
  is_primary boolean not null default true,
  target_value real,
  target_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.fitness_baselines (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  baseline_date date not null,
  push_ups_reps int,
  squats_reps int,
  pull_ups_reps int,
  plank_seconds int,
  walk_jog_minutes int,
  notes text,
  created_at timestamptz not null default now()
);

-- ============================================================
-- Exercise library (global reference data, readable by all authenticated
-- users; not user-owned, so no per-row RLS beyond read-only).
-- ============================================================

create table public.exercises (
  id uuid primary key,
  name text not null,
  category text not null,
  primary_muscles_json jsonb not null default '[]',
  secondary_muscles_json jsonb not null default '[]',
  equipment_json jsonb not null default '[]',
  difficulty text not null,
  instructions text not null,
  form_cues_json jsonb not null default '[]',
  common_mistakes_json jsonb not null default '[]',
  beginner_variant_id uuid,
  advanced_variant_id uuid,
  progression_id uuid,
  regression_id uuid
);

create table public.exercise_progressions (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  exercise_id uuid not null references public.exercises (id),
  recorded_at timestamptz not null,
  metric_type text not null,
  value real not null,
  rpe int,
  notes text,
  event_id uuid not null unique,
  created_at timestamptz not null default now()
);

-- ============================================================
-- Workouts
-- ============================================================

create table public.workout_plans (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  strategy_notes text,
  is_active boolean not null default true,
  start_date date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version int not null default 1
);

create table public.workouts (
  id uuid primary key,
  plan_id uuid references public.workout_plans (id) on delete set null,
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  workout_type text not null,
  scheduled_date date not null,
  estimated_minutes int,
  status text not null default 'scheduled',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.workout_exercises (
  id uuid primary key,
  workout_id uuid not null references public.workouts (id) on delete cascade,
  exercise_id uuid not null references public.exercises (id),
  order_index int not null,
  target_sets int,
  target_reps int,
  target_weight_kg real,
  target_duration_seconds int,
  rest_seconds int
);

create table public.workout_sets (
  id uuid primary key,
  workout_exercise_id uuid not null references public.workout_exercises (id) on delete cascade,
  set_index int not null,
  target_reps int,
  actual_reps int,
  target_weight_kg real,
  actual_weight_kg real,
  rpe int,
  outcome text,
  event_id uuid unique,
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.workout_completions (
  id uuid primary key,
  workout_id uuid not null references public.workouts (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  status text not null,
  skip_reason_code text,
  feeling text,
  duration_seconds int,
  event_id uuid not null unique,
  completed_at timestamptz not null,
  created_at timestamptz not null default now()
);

-- ============================================================
-- Health / body metrics
-- ============================================================

create table public.step_records (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  date date not null,
  steps int not null,
  target int,
  source text not null,
  updated_at timestamptz not null default now(),
  unique (user_id, date)
);

create table public.cardio_sessions (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  activity_type text not null,
  distance_meters real,
  duration_seconds int not null,
  started_at timestamptz not null,
  event_id uuid not null unique,
  created_at timestamptz not null default now()
);

create table public.hiit_sessions (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  workout_id uuid references public.workouts (id) on delete set null,
  rounds int not null,
  work_seconds int not null,
  rest_seconds int not null,
  total_duration_seconds int not null,
  event_id uuid not null unique,
  completed_at timestamptz not null,
  created_at timestamptz not null default now()
);

create table public.weight_logs (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  weight_kg real not null,
  recorded_at timestamptz not null,
  event_id uuid not null unique,
  created_at timestamptz not null default now()
);

create table public.body_composition_logs (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  body_fat_percent real,
  muscle_mass_kg real,
  source text,
  recorded_at timestamptz not null,
  event_id uuid not null unique,
  created_at timestamptz not null default now()
);

create table public.measurement_logs (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  measurement_type text not null,
  value_cm real not null,
  recorded_at timestamptz not null,
  event_id uuid not null unique,
  created_at timestamptz not null default now()
);

-- ============================================================
-- Nutrition
-- ============================================================

create table public.nutrition_goals (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  calorie_target int not null,
  protein_grams real not null,
  carbs_grams real not null,
  fat_grams real not null,
  calculation_method text not null,
  updated_at timestamptz not null default now(),
  version int not null default 1,
  unique (user_id)
);

create table public.foods (
  id uuid primary key,
  name text not null,
  brand text,
  calories real not null,
  protein_grams real not null,
  carbs_grams real not null,
  fat_grams real not null,
  serving_unit text not null,
  serving_size real not null
);

create table public.meals (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  date date not null,
  meal_type text not null,
  name text not null,
  ingredients_json jsonb not null default '[]',
  calories real not null,
  protein_grams real not null,
  carbs_grams real not null,
  fat_grams real not null,
  created_at timestamptz not null default now()
);

create table public.meal_logs (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  meal_id uuid references public.meals (id) on delete set null,
  food_id uuid references public.foods (id) on delete set null,
  date date not null,
  meal_type text not null,
  quantity real not null default 1,
  calories real not null,
  protein_grams real not null,
  carbs_grams real not null,
  fat_grams real not null,
  event_id uuid not null unique,
  logged_at timestamptz not null
);

-- ============================================================
-- Accountability
-- ============================================================

create table public.daily_plans (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  date date not null,
  created_at timestamptz not null default now(),
  unique (user_id, date)
);

create table public.daily_tasks (
  id uuid primary key,
  daily_plan_id uuid not null references public.daily_plans (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  task_type text not null,
  ref_id uuid,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.task_completions (
  id uuid primary key,
  daily_task_id uuid not null references public.daily_tasks (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  status text not null,
  skip_reason_code text,
  note text,
  event_id uuid not null unique,
  completed_at timestamptz not null
);

create table public.coach_events (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  event_type text not null,
  payload_json jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create table public.coach_insights (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  insight_type text not null,
  message text not null,
  dismissed boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.notification_preferences (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  category text not null,
  enabled boolean not null default true,
  quiet_hours_start_minute int,
  quiet_hours_end_minute int,
  updated_at timestamptz not null default now(),
  unique (user_id, category)
);

-- ============================================================
-- Progress
-- ============================================================

create table public.achievements (
  id uuid primary key,
  key text not null unique,
  title text not null,
  description text not null,
  icon text not null
);

create table public.achievement_unlocks (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  achievement_id uuid not null references public.achievements (id),
  event_id uuid not null unique,
  unlocked_at timestamptz not null
);

create table public.personal_records (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  record_type text not null,
  exercise_id uuid references public.exercises (id),
  value real not null,
  unit text not null,
  event_id uuid not null unique,
  recorded_at timestamptz not null
);

-- ============================================================
-- Community / challenges (shared reference data + per-user participation)
-- ============================================================

create table public.challenges (
  id uuid primary key,
  key text not null unique,
  title text not null,
  description text not null,
  target_type text not null,
  target_value real not null,
  start_date date not null,
  end_date date not null
);

create table public.challenge_participations (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  challenge_id uuid not null references public.challenges (id) on delete cascade,
  progress_value real not null default 0,
  joined_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (user_id, challenge_id)
);

-- ============================================================
-- Indexes for common access patterns
-- ============================================================

create index on public.workouts (user_id, scheduled_date);
create index on public.daily_tasks (daily_plan_id);
create index on public.weight_logs (user_id, recorded_at desc);
create index on public.step_records (user_id, date desc);
create index on public.meal_logs (user_id, date);
create index on public.exercise_progressions (user_id, exercise_id, recorded_at desc);
create index on public.challenge_participations (challenge_id);

-- ============================================================
-- Row Level Security
-- ============================================================

alter table public.user_profiles enable row level security;
alter table public.fitness_goals enable row level security;
alter table public.fitness_baselines enable row level security;
alter table public.exercise_progressions enable row level security;
alter table public.workout_plans enable row level security;
alter table public.workouts enable row level security;
alter table public.workout_exercises enable row level security;
alter table public.workout_sets enable row level security;
alter table public.workout_completions enable row level security;
alter table public.step_records enable row level security;
alter table public.cardio_sessions enable row level security;
alter table public.hiit_sessions enable row level security;
alter table public.weight_logs enable row level security;
alter table public.body_composition_logs enable row level security;
alter table public.measurement_logs enable row level security;
alter table public.nutrition_goals enable row level security;
alter table public.meals enable row level security;
alter table public.meal_logs enable row level security;
alter table public.daily_plans enable row level security;
alter table public.daily_tasks enable row level security;
alter table public.task_completions enable row level security;
alter table public.coach_events enable row level security;
alter table public.coach_insights enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.achievement_unlocks enable row level security;
alter table public.personal_records enable row level security;
alter table public.challenge_participations enable row level security;

-- Reference/global tables: readable by any authenticated user, writable by
-- no one from the client (seeded via migration/Edge Function only).
alter table public.exercises enable row level security;
alter table public.foods enable row level security;
alter table public.achievements enable row level security;
alter table public.challenges enable row level security;

create policy "exercises_read_all" on public.exercises for select to authenticated using (true);
create policy "foods_read_all" on public.foods for select to authenticated using (true);
create policy "achievements_read_all" on public.achievements for select to authenticated using (true);
create policy "challenges_read_all" on public.challenges for select to authenticated using (true);

-- Standard owner-only policy, generated per table. `user_profiles` uses
-- auth_user_id as the owning column; every other table uses user_id.

create policy "user_profiles_owner" on public.user_profiles
  for all to authenticated
  using (auth_user_id = (select auth.uid()))
  with check (auth_user_id = (select auth.uid()));

do $$
declare
  t text;
  owner_tables text[] := array[
    'fitness_goals', 'fitness_baselines', 'exercise_progressions',
    'workout_plans', 'workouts', 'workout_completions',
    'step_records', 'cardio_sessions', 'hiit_sessions',
    'weight_logs', 'body_composition_logs', 'measurement_logs',
    'nutrition_goals', 'meals', 'meal_logs',
    'daily_plans', 'daily_tasks', 'task_completions',
    'coach_events', 'coach_insights', 'notification_preferences',
    'achievement_unlocks', 'personal_records', 'challenge_participations'
  ];
begin
  foreach t in array owner_tables loop
    execute format(
      'create policy "%1$s_owner" on public.%1$s for all to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));',
      t
    );
  end loop;
end $$;

-- workout_exercises / workout_sets are owned indirectly through their
-- parent workout — scope via a join rather than a duplicated user_id.

create policy "workout_exercises_owner" on public.workout_exercises
  for all to authenticated
  using (exists (
    select 1 from public.workouts w
    where w.id = workout_exercises.workout_id and w.user_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from public.workouts w
    where w.id = workout_exercises.workout_id and w.user_id = (select auth.uid())
  ));

create policy "workout_sets_owner" on public.workout_sets
  for all to authenticated
  using (exists (
    select 1 from public.workout_exercises we
    join public.workouts w on w.id = we.workout_id
    where we.id = workout_sets.workout_exercise_id and w.user_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from public.workout_exercises we
    join public.workouts w on w.id = we.workout_id
    where we.id = workout_sets.workout_exercise_id and w.user_id = (select auth.uid())
  ));
