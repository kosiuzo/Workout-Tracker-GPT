-- =====================================================
-- Flattened Sessions Table Migration
-- =====================================================
-- Creates a denormalized table with one row per set
-- per exercise per session, flattening the JSONB structure
-- =====================================================

-- =====================================================
-- 1. CREATE FLATTENED SESSIONS TABLE
-- =====================================================
-- Each row represents a single set in a workout session

create table if not exists sessions_flat (
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

  -- Composite primary key: workout_name + session_date + exercise_name + set_number uniquely identifies a row
  primary key (workout_name, session_date, exercise_name, set_number)
);

-- =====================================================
-- 2. INDEXES FOR EFFICIENT QUERYING
-- =====================================================

-- Index for querying by workout name
create index if not exists idx_sessions_flat_workout_name
  on sessions_flat(workout_name);

-- Index for querying by date
create index if not exists idx_sessions_flat_date
  on sessions_flat(session_date desc);

-- Index for querying by exercise name
create index if not exists idx_sessions_flat_exercise_name
  on sessions_flat(exercise_name);

-- Composite index for common query pattern: workout_name + date
create index if not exists idx_sessions_flat_workout_date
  on sessions_flat(workout_name, session_date desc);

-- Composite index for common query pattern: exercise + date
create index if not exists idx_sessions_flat_exercise_date
  on sessions_flat(exercise_name, session_date desc);

-- =====================================================
-- 3. COMMENTS FOR DOCUMENTATION
-- =====================================================

comment on table sessions_flat is 'Denormalized session table with one row per set per exercise per session (primary structure after migrating from JSON)';
comment on column sessions_flat.set_number is 'Set number for this exercise (1, 2, 3, etc.)';
comment on column sessions_flat.weight is 'Weight used for this set (supports decimal values)';

-- =====================================================
-- 4. UPDATE TIMESTAMP TRIGGER
-- =====================================================
-- Automatically update updated_at timestamp on any change

create or replace function update_sessions_flat_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger update_sessions_flat_updated_at
  before update on sessions_flat
  for each row
  execute function update_sessions_flat_updated_at();

comment on trigger update_sessions_flat_updated_at on sessions_flat is 'Automatically updates updated_at timestamp whenever a row is modified';

-- =====================================================
-- 5. ROW LEVEL SECURITY
-- =====================================================

alter table sessions_flat enable row level security;

-- Allow all operations for anonymous users (single-user mode)
create policy "Allow all for anon users" on sessions_flat
  for all using (true) with check (true);
