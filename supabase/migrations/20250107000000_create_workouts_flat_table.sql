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
  id uuid primary key default gen_random_uuid(),

  -- Workout-level fields (denormalized from workouts table)
  workout_id uuid references workouts(id) on delete cascade,
  workout_name text not null,
  workout_description text,
  workout_is_active boolean not null,

  -- Day information
  day_name text not null,

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

  -- Ensure one row per workout per day per exercise order
  unique (workout_id, day_name, exercise_order)
);

-- =====================================================
-- 2. INDEXES FOR EFFICIENT QUERYING
-- =====================================================

-- Index for querying by workout
create index if not exists idx_workouts_flat_workout_id
  on workouts_flat(workout_id);

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

-- Composite index for common query pattern: workout + day
create index if not exists idx_workouts_flat_workout_day
  on workouts_flat(workout_id, day_name);

-- Index for superset queries
create index if not exists idx_workouts_flat_superset
  on workouts_flat(workout_id, day_name, superset_group)
  where superset_group is not null;

-- =====================================================
-- 3. COMMENTS FOR DOCUMENTATION
-- =====================================================

comment on table workouts_flat is 'Denormalized workout table with one row per exercise per day per workout';
comment on column workouts_flat.exercise_order is 'Zero-indexed position of exercise in the day''s exercise array';
comment on column workouts_flat.superset_group is 'Exercises with same superset_group should be performed together (e.g., "A", "B", "C")';

-- =====================================================
-- 4. SYNC FUNCTION
-- =====================================================
-- Function to populate/refresh workouts_flat from workouts table

create or replace function sync_workouts_flat()
returns void as $$
begin
  -- Clear existing flat data
  truncate table workouts_flat;

  -- Insert flattened data from workouts table
  insert into workouts_flat (
    workout_id,
    workout_name,
    workout_description,
    workout_is_active,
    day_name,
    exercise_order,
    exercise_name,
    sets,
    reps,
    weight,
    superset_group,
    exercise_notes
  )
  select
    w.id as workout_id,
    w.name as workout_name,
    w.description as workout_description,
    w.is_active as workout_is_active,
    day_entry.key as day_name,
    exercise_idx as exercise_order,
    exercise->>'exercise' as exercise_name,
    (exercise->>'sets')::int as sets,
    (exercise->>'reps')::int as reps,
    (exercise->>'weight')::int as weight,
    exercise->>'superset_group' as superset_group,
    exercise->>'notes' as exercise_notes
  from workouts w,
    jsonb_each(w.days) as day_entry,
    jsonb_array_elements(day_entry.value) with ordinality as exercises(exercise, exercise_idx)
  where jsonb_typeof(day_entry.value) = 'array'
  order by w.id, day_entry.key, exercise_idx;
end;
$$ language plpgsql;

comment on function sync_workouts_flat() is 'Fully refreshes workouts_flat table from workouts table JSONB data';

-- =====================================================
-- 5. TRIGGER FUNCTION FOR AUTO-SYNC
-- =====================================================
-- Automatically sync flat table when workouts are modified

create or replace function sync_workouts_flat_on_change()
returns trigger as $$
begin
  -- For INSERT and UPDATE, refresh all rows for this workout
  if (TG_OP = 'INSERT' or TG_OP = 'UPDATE') then
    -- Delete existing rows for this workout
    delete from workouts_flat where workout_id = NEW.id;

    -- Insert new flattened rows
    insert into workouts_flat (
      workout_id,
      workout_name,
      workout_description,
      workout_is_active,
      day_name,
      exercise_order,
      exercise_name,
      sets,
      reps,
      weight,
      superset_group,
      exercise_notes
    )
    select
      NEW.id as workout_id,
      NEW.name as workout_name,
      NEW.description as workout_description,
      NEW.is_active as workout_is_active,
      day_entry.key as day_name,
      exercise_idx - 1 as exercise_order,
      exercise->>'exercise' as exercise_name,
      (exercise->>'sets')::int as sets,
      (exercise->>'reps')::int as reps,
      (exercise->>'weight')::int as weight,
      exercise->>'superset_group' as superset_group,
      exercise->>'notes' as exercise_notes
    from jsonb_each(NEW.days) as day_entry,
      jsonb_array_elements(day_entry.value) with ordinality as exercises(exercise, exercise_idx)
    where jsonb_typeof(day_entry.value) = 'array';

    return NEW;
  end if;

  -- For DELETE, rows cascade automatically due to foreign key
  if (TG_OP = 'DELETE') then
    return OLD;
  end if;

  return NULL;
end;
$$ language plpgsql;

-- =====================================================
-- 6. ATTACH TRIGGER
-- =====================================================

create trigger sync_workouts_flat_trigger
  after insert or update or delete on workouts
  for each row
  execute function sync_workouts_flat_on_change();

comment on trigger sync_workouts_flat_trigger on workouts is 'Automatically syncs workouts_flat table when workouts are modified';

-- =====================================================
-- 7. ROW LEVEL SECURITY
-- =====================================================

alter table workouts_flat enable row level security;

-- Allow all operations for anonymous users (single-user mode)
create policy "Allow all for anon users" on workouts_flat
  for all using (true) with check (true);

-- =====================================================
-- 8. INITIAL POPULATION
-- =====================================================
-- Populate flat table with existing workout data

select sync_workouts_flat();
