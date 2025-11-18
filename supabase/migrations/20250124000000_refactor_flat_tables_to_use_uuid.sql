-- =====================================================
-- Refactor Flat Tables: Add UUID IDs and Float Exercise Order
-- =====================================================
-- This migration refactors workouts_flat and sessions_flat tables:
-- 1. Rename workouts_flat to workouts
-- 2. Add uuid primary key to workouts
-- 3. Change exercise_order from int to float for easier rearrangement
-- 4. Rename sessions_flat to sessions
-- 5. Add uuid primary key to sessions
-- =====================================================

-- =====================================================
-- 1. CREATE NEW WORKOUTS TABLE (replacing workouts_flat)
-- =====================================================

create table if not exists workouts (
  id uuid primary key default gen_random_uuid(),

  -- Workout-level fields (denormalized from workouts table)
  workout_name text not null,
  workout_description text,
  workout_is_active boolean not null,

  -- Day information
  day_name text not null,
  day_notes text,

  -- Exercise information (from JSONB array)
  exercise_order float not null, -- Float allows easier rearrangement (1.5 between 1 and 2)
  exercise_name text not null,
  sets int,
  reps int,
  weight int,
  superset_group text,
  exercise_notes text,

  -- Timestamps
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),

  -- Ensure unique exercises per workout/day/order
  unique(id, workout_name, day_name, exercise_order)
);

-- =====================================================
-- 2. MIGRATE DATA FROM workouts_flat TO workouts
-- =====================================================

insert into workouts (
  id,
  workout_name,
  workout_description,
  workout_is_active,
  day_name,
  day_notes,
  exercise_order,
  exercise_name,
  sets,
  reps,
  weight,
  superset_group,
  exercise_notes,
  created_at,
  updated_at
)
select
  gen_random_uuid(),
  workout_name,
  workout_description,
  workout_is_active,
  day_name,
  day_notes,
  exercise_order::float,
  exercise_name,
  sets,
  reps,
  weight,
  superset_group,
  exercise_notes,
  created_at,
  updated_at
from workouts_flat
on conflict do nothing;

-- =====================================================
-- 3. CREATE INDEXES FOR WORKOUTS TABLE
-- =====================================================

create index if not exists idx_workouts_id
  on workouts(id);

create index if not exists idx_workouts_workout_name
  on workouts(workout_name);

create index if not exists idx_workouts_day_name
  on workouts(day_name);

create index if not exists idx_workouts_exercise_name
  on workouts(exercise_name);

create index if not exists idx_workouts_active
  on workouts(workout_is_active)
  where workout_is_active = true;

create index if not exists idx_workouts_workout_day
  on workouts(workout_name, day_name);

create index if not exists idx_workouts_superset
  on workouts(workout_name, day_name, superset_group)
  where superset_group is not null;

-- =====================================================
-- 4. CREATE UPDATE TRIGGER FOR WORKOUTS TABLE
-- =====================================================

create or replace function update_workouts_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists update_workouts_updated_at on workouts;

create trigger update_workouts_updated_at
  before update on workouts
  for each row
  execute function update_workouts_updated_at();

-- =====================================================
-- 5. ENABLE RLS FOR WORKOUTS TABLE
-- =====================================================

alter table workouts enable row level security;

drop policy if exists "Allow all for anon users" on workouts;

create policy "Allow all for anon users" on workouts
  for all using (true) with check (true);

-- =====================================================
-- 6. CREATE NEW SESSIONS TABLE (replacing sessions_flat)
-- =====================================================

create table if not exists sessions (
  id uuid primary key default gen_random_uuid(),

  -- Session-level fields (denormalized from sessions table)
  workout_name text not null,
  session_date date not null,
  session_notes text,

  -- Exercise information (from JSONB array)
  exercise_name text not null,
  set_number int not null,
  reps int not null,
  weight numeric(10,2) not null,

  -- Timestamps
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),

  -- Ensure unique sets per session
  unique(id, workout_name, session_date, exercise_name, set_number)
);

-- =====================================================
-- 7. MIGRATE DATA FROM sessions_flat TO sessions
-- =====================================================

insert into sessions (
  id,
  workout_name,
  session_date,
  session_notes,
  exercise_name,
  set_number,
  reps,
  weight,
  created_at,
  updated_at
)
select
  gen_random_uuid(),
  workout_name,
  session_date,
  session_notes,
  exercise_name,
  set_number,
  reps,
  weight,
  created_at,
  updated_at
from sessions_flat
on conflict do nothing;

-- =====================================================
-- 8. CREATE INDEXES FOR SESSIONS TABLE
-- =====================================================

create index if not exists idx_sessions_id
  on sessions(id);

create index if not exists idx_sessions_workout_name
  on sessions(workout_name);

create index if not exists idx_sessions_date
  on sessions(session_date desc);

create index if not exists idx_sessions_exercise_name
  on sessions(exercise_name);

create index if not exists idx_sessions_workout_date
  on sessions(workout_name, session_date desc);

create index if not exists idx_sessions_exercise_date
  on sessions(exercise_name, session_date desc);

-- =====================================================
-- 9. CREATE UPDATE TRIGGER FOR SESSIONS TABLE
-- =====================================================

create or replace function update_sessions_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists update_sessions_updated_at on sessions;

create trigger update_sessions_updated_at
  before update on sessions
  for each row
  execute function update_sessions_updated_at();

-- =====================================================
-- 10. ENABLE RLS FOR SESSIONS TABLE
-- =====================================================

alter table sessions enable row level security;

drop policy if exists "Allow all for anon users" on sessions;

create policy "Allow all for anon users" on sessions
  for all using (true) with check (true);

-- =====================================================
-- 11. ADD COMMENTS FOR DOCUMENTATION
-- =====================================================

comment on table workouts is 'Denormalized workout table with one row per exercise per day per workout, identified by UUID. Migrated from workouts_flat with UUID primary key and float exercise_order for flexible rearrangement.';

comment on column workouts.id is 'Unique identifier for this exercise instance';
comment on column workouts.exercise_order is 'Float position of exercise in day (allows rearrangement like 1.5 between 1 and 2)';
comment on column workouts.day_notes is 'Notes specific to this workout day (e.g., how you felt, difficulty, adjustments made)';
comment on column workouts.superset_group is 'Exercises with same superset_group should be performed together (e.g., "A", "B", "C")';

comment on table sessions is 'Denormalized session table with one row per set per exercise per session, identified by UUID. Migrated from sessions_flat with UUID primary key for unique identification.';

comment on column sessions.id is 'Unique identifier for this set instance';
comment on column sessions.set_number is 'Set number for this exercise (1, 2, 3, etc.)';
comment on column sessions.weight is 'Weight used for this set (supports decimal values)';

-- =====================================================
-- 12. DROP OLD TABLES
-- =====================================================
-- Keep these old tables for now in case we need to rollback
-- They can be dropped in a future migration after validation

-- drop table if exists workouts_flat cascade;
-- drop table if exists sessions_flat cascade;
