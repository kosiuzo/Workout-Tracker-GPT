-- =====================================================
-- Flattened Workouts Table Migration
-- =====================================================
-- Creates a denormalized table with one row per exercise
-- per day per workout, flattening the JSONB structure
-- =====================================================

-- =====================================================
-- 1. CREATE FLATTENED WORKOUTS TABLE
-- =====================================================
-- Each row represents a single exercise in a workout day

create table if not exists workouts_flat (
  -- Workout-level fields (denormalized from workouts table)
  workout_name text not null,
  workout_description text,
  workout_is_active boolean not null,

  -- Day information
  day_name text not null,
  day_notes text,

  -- Exercise information (from JSONB array)
  exercise_order int not null, -- Position in the array (0-indexed)
  exercise_name text not null,
  sets int,
  reps int,
  weight int,
  superset_group text,
  exercise_notes text,

  -- Timestamps
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),

  -- Composite primary key: workout_name + day_name + exercise_order uniquely identifies a row
  primary key (workout_name, day_name, exercise_order)
);

-- =====================================================
-- 2. INDEXES FOR EFFICIENT QUERYING
-- =====================================================

-- Index for querying by workout name
create index if not exists idx_workouts_flat_workout_name
  on workouts_flat(workout_name);

-- Index for querying by day
create index if not exists idx_workouts_flat_day_name
  on workouts_flat(day_name);

-- Index for querying by exercise name
create index if not exists idx_workouts_flat_exercise_name
  on workouts_flat(exercise_name);

-- Index for querying active workouts
create index if not exists idx_workouts_flat_active
  on workouts_flat(workout_is_active)
  where workout_is_active = true;

-- Composite index for common query pattern: workout_name + day
create index if not exists idx_workouts_flat_workout_day
  on workouts_flat(workout_name, day_name);

-- Index for superset queries
create index if not exists idx_workouts_flat_superset
  on workouts_flat(workout_name, day_name, superset_group)
  where superset_group is not null;

-- =====================================================
-- 3. COMMENTS FOR DOCUMENTATION
-- =====================================================

comment on table workouts_flat is 'Denormalized workout table with one row per exercise per day per workout (primary structure after migrating from JSON)';
comment on column workouts_flat.exercise_order is 'Zero-indexed position of exercise in the day''s exercise array';
comment on column workouts_flat.day_notes is 'Notes specific to this workout day (e.g., how you felt, difficulty, adjustments made)';
comment on column workouts_flat.superset_group is 'Exercises with same superset_group should be performed together (e.g., "A", "B", "C")';

-- =====================================================
-- 4. UPDATE TIMESTAMP TRIGGER
-- =====================================================
-- Automatically update updated_at timestamp on any change

create or replace function update_workouts_flat_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger update_workouts_flat_updated_at
  before update on workouts_flat
  for each row
  execute function update_workouts_flat_updated_at();

comment on trigger update_workouts_flat_updated_at on workouts_flat is 'Automatically updates updated_at timestamp whenever a row is modified';

-- =====================================================
-- 5. ROW LEVEL SECURITY
-- =====================================================

alter table workouts_flat enable row level security;

-- Allow all operations for anonymous users (single-user mode)
create policy "Allow all for anon users" on workouts_flat
  for all using (true) with check (true);
