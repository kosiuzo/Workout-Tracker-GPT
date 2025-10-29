-- =====================================================
-- Workout Tracker GPT v1.0 - Database Schema
-- =====================================================
-- Creates core tables for workout tracking system with
-- JSONB-based flexible structure for exercises and sessions
-- =====================================================

-- =====================================================
-- 1. WORKOUTS TABLE
-- =====================================================
-- Stores workout templates with all days, exercises, and metadata
-- Supports flexible JSON structure for supersets, notes, etc.

create table if not exists workouts (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  days jsonb not null default '{}'::jsonb,
  is_active boolean default false,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Only one active workout allowed at a time
create unique index if not exists one_active_workout
  on workouts ((is_active))
  where is_active = true;

-- Index for quick lookup of active workout
create index if not exists idx_workouts_active
  on workouts(is_active)
  where is_active = true;

-- Index for name search
create index if not exists idx_workouts_name
  on workouts(name);

-- Add comment for documentation
comment on table workouts is 'Workout templates with flexible JSONB structure for days and exercises';
comment on column workouts.days is 'JSONB object with day names as keys and exercise arrays as values. Example: {"monday": [{"exercise": "Bench Press", "sets": 3, "reps": 10, "weight": 135, "superset_group": "A"}]}';
comment on column workouts.is_active is 'Only one workout can be active at a time (enforced by unique index)';

-- =====================================================
-- 2. SESSIONS TABLE
-- =====================================================
-- Logs what was actually performed in a workout session
-- Uses JSONB array for flexible set-by-set logging

create table if not exists sessions (
  id uuid primary key default gen_random_uuid(),
  workout_id uuid references workouts(id) on delete cascade,
  date date not null default current_date,
  entries jsonb not null default '[]'::jsonb,
  notes text,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Indexes for efficient querying
create index if not exists idx_sessions_date
  on sessions(date desc);

create index if not exists idx_sessions_workout_id
  on sessions(workout_id);

create index if not exists idx_sessions_workout_date
  on sessions(workout_id, date desc);

-- Add comments
comment on table sessions is 'Individual workout session logs with set-by-set entries';
comment on column sessions.entries is 'JSONB array of performed sets. Example: [{"exercise": "Bench Press", "set": 1, "reps": 10, "weight": 135}, {"exercise": "Bench Press", "set": 2, "reps": 9, "weight": 145}]';

-- =====================================================
-- 3. EXERCISE_HISTORY TABLE
-- =====================================================
-- Aggregated daily totals per workout per exercise
-- Computed incrementally via RPC functions

create table if not exists exercise_history (
  id uuid primary key default gen_random_uuid(),
  workout_id uuid references workouts(id) on delete cascade,
  exercise_name text not null,
  date date not null,
  total_sets int not null default 0,
  total_reps int not null default 0,
  total_volume int not null default 0,
  max_weight int not null default 0,
  avg_weight numeric(10,2),
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),
  unique (workout_id, exercise_name, date)
);

-- Indexes for efficient aggregation and querying
create index if not exists idx_exercise_history_workout
  on exercise_history(workout_id);

create index if not exists idx_exercise_history_date
  on exercise_history(date desc);

create index if not exists idx_exercise_history_exercise
  on exercise_history(exercise_name);

create index if not exists idx_exercise_history_workout_date
  on exercise_history(workout_id, date desc);

create index if not exists idx_exercise_history_exercise_date
  on exercise_history(exercise_name, date desc);

-- Add comments
comment on table exercise_history is 'Daily aggregated totals per exercise per workout';
comment on column exercise_history.total_volume is 'Sum of (weight × reps) for all sets';
comment on column exercise_history.max_weight is 'Maximum weight used across all sets';

-- =====================================================
-- 4. WORKOUT_HISTORY TABLE
-- =====================================================
-- Aggregated daily totals per workout
-- Rolled up from exercise_history

create table if not exists workout_history (
  id uuid primary key default gen_random_uuid(),
  workout_id uuid references workouts(id) on delete cascade,
  date date not null,
  total_volume int not null default 0,
  total_sets int not null default 0,
  total_reps int not null default 0,
  num_exercises int not null default 0,
  duration_minutes int,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),
  unique (workout_id, date)
);

-- Indexes for efficient querying
create index if not exists idx_workout_history_date
  on workout_history(date desc);

create index if not exists idx_workout_history_workout
  on workout_history(workout_id);

create index if not exists idx_workout_history_workout_date
  on workout_history(workout_id, date desc);

-- Add comments
comment on table workout_history is 'Daily aggregated totals per workout (rolled up from exercise_history)';
comment on column workout_history.total_volume is 'Sum of total_volume from all exercises for this workout on this date';
comment on column workout_history.num_exercises is 'Count of distinct exercises performed';

-- =====================================================
-- 5. TRIGGERS FOR UPDATED_AT
-- =====================================================
-- Automatically update updated_at timestamp on row changes

create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Apply triggers to all tables with updated_at
create trigger update_workouts_updated_at
  before update on workouts
  for each row
  execute function update_updated_at_column();

create trigger update_sessions_updated_at
  before update on sessions
  for each row
  execute function update_updated_at_column();

create trigger update_exercise_history_updated_at
  before update on exercise_history
  for each row
  execute function update_updated_at_column();

create trigger update_workout_history_updated_at
  before update on workout_history
  for each row
  execute function update_updated_at_column();

-- =====================================================
-- 6. ROW LEVEL SECURITY (RLS)
-- =====================================================
-- Enable RLS for future multi-user support
-- Currently allowing all operations for single-user mode

alter table workouts enable row level security;
alter table sessions enable row level security;
alter table exercise_history enable row level security;
alter table workout_history enable row level security;

-- Allow all operations for anonymous users (single-user mode)
create policy "Allow all for anon users" on workouts
  for all using (true) with check (true);

create policy "Allow all for anon users" on sessions
  for all using (true) with check (true);

create policy "Allow all for anon users" on exercise_history
  for all using (true) with check (true);

create policy "Allow all for anon users" on workout_history
  for all using (true) with check (true);
