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
  id uuid primary key default gen_random_uuid(),

  -- Session-level fields (denormalized from sessions table)
  session_id uuid references sessions(id) on delete cascade,
  workout_id uuid,
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

  -- Ensure one row per session per exercise per set number
  unique (session_id, exercise_name, set_number)
);

-- =====================================================
-- 2. INDEXES FOR EFFICIENT QUERYING
-- =====================================================

-- Index for querying by session
create index if not exists idx_sessions_flat_session_id
  on sessions_flat(session_id);

-- Index for querying by workout
create index if not exists idx_sessions_flat_workout_id
  on sessions_flat(workout_id);

-- Index for querying by date
create index if not exists idx_sessions_flat_date
  on sessions_flat(session_date desc);

-- Index for querying by exercise name
create index if not exists idx_sessions_flat_exercise_name
  on sessions_flat(exercise_name);

-- Composite index for common query pattern: workout + date
create index if not exists idx_sessions_flat_workout_date
  on sessions_flat(workout_id, session_date desc);

-- Composite index for common query pattern: exercise + date
create index if not exists idx_sessions_flat_exercise_date
  on sessions_flat(exercise_name, session_date desc);

-- Composite index for session + exercise (for grouping sets)
create index if not exists idx_sessions_flat_session_exercise
  on sessions_flat(session_id, exercise_name, set_number);

-- =====================================================
-- 3. COMMENTS FOR DOCUMENTATION
-- =====================================================

comment on table sessions_flat is 'Denormalized session table with one row per set per exercise per session';
comment on column sessions_flat.set_number is 'Set number for this exercise (1, 2, 3, etc.)';
comment on column sessions_flat.weight is 'Weight used for this set (supports decimal values)';

-- =====================================================
-- 4. SYNC FUNCTION
-- =====================================================
-- Function to populate/refresh sessions_flat from sessions table

create or replace function sync_sessions_flat()
returns void as $$
begin
  -- Clear existing flat data
  truncate table sessions_flat;

  -- Insert flattened data from sessions table
  insert into sessions_flat (
    session_id,
    workout_id,
    session_date,
    session_notes,
    exercise_name,
    set_number,
    reps,
    weight
  )
  select
    s.id as session_id,
    s.workout_id,
    s.date as session_date,
    s.notes as session_notes,
    entry->>'exercise' as exercise_name,
    (entry->>'set')::int as set_number,
    (entry->>'reps')::int as reps,
    (entry->>'weight')::numeric as weight
  from sessions s,
    jsonb_array_elements(s.entries) as entry
  where entry->>'exercise' is not null
    and entry->>'set' is not null
    and entry->>'reps' is not null
    and entry->>'weight' is not null
  order by s.id, exercise_name, set_number;
end;
$$ language plpgsql;

comment on function sync_sessions_flat() is 'Fully refreshes sessions_flat table from sessions table JSONB data';

-- =====================================================
-- 5. TRIGGER FUNCTION FOR AUTO-SYNC
-- =====================================================
-- Automatically sync flat table when sessions are modified

create or replace function sync_sessions_flat_on_change()
returns trigger as $$
begin
  -- For INSERT and UPDATE, refresh all rows for this session
  if (TG_OP = 'INSERT' or TG_OP = 'UPDATE') then
    -- Delete existing rows for this session
    delete from sessions_flat where session_id = NEW.id;

    -- Insert new flattened rows
    insert into sessions_flat (
      session_id,
      workout_id,
      session_date,
      session_notes,
      exercise_name,
      set_number,
      reps,
      weight
    )
    select
      NEW.id as session_id,
      NEW.workout_id,
      NEW.date as session_date,
      NEW.notes as session_notes,
      entry->>'exercise' as exercise_name,
      (entry->>'set')::int as set_number,
      (entry->>'reps')::int as reps,
      (entry->>'weight')::numeric as weight
    from jsonb_array_elements(NEW.entries) as entry
    where entry->>'exercise' is not null
      and entry->>'set' is not null
      and entry->>'reps' is not null
      and entry->>'weight' is not null;

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

create trigger sync_sessions_flat_trigger
  after insert or update or delete on sessions
  for each row
  execute function sync_sessions_flat_on_change();

comment on trigger sync_sessions_flat_trigger on sessions is 'Automatically syncs sessions_flat table when sessions are modified';

-- =====================================================
-- 7. ROW LEVEL SECURITY
-- =====================================================

alter table sessions_flat enable row level security;

-- Allow all operations for anonymous users (single-user mode)
create policy "Allow all for anon users" on sessions_flat
  for all using (true) with check (true);

-- =====================================================
-- 8. INITIAL POPULATION
-- =====================================================
-- Populate flat table with existing session data

select sync_sessions_flat();
