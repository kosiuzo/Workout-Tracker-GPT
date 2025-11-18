-- =====================================================
-- Update Sessions Table Schema
-- =====================================================
-- This migration updates the sessions table to use "sets" instead of "set_number"
-- Changes one row per exercise per session (representing "X sets of Y reps at Z weight")
-- instead of one row per individual set
-- =====================================================

-- =====================================================
-- 1. CREATE NEW SESSIONS TABLE WITH UPDATED SCHEMA
-- =====================================================

create table if not exists sessions_new (
  id uuid primary key default gen_random_uuid(),

  -- Session-level fields
  workout_name text not null,
  session_date date not null,
  session_notes text,

  -- Exercise information
  exercise_name text not null,
  sets int not null,              -- Number of sets performed (e.g., 3)
  reps int not null,              -- Reps per set (e.g., 10)
  weight numeric(10,2) not null,  -- Weight used

  -- Timestamps
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- =====================================================
-- 2. MIGRATE DATA FROM sessions TO sessions_new
-- =====================================================
-- Group by exercise and aggregate set_number as count, keeping max reps/weight per exercise

insert into sessions_new (
  id,
  workout_name,
  session_date,
  session_notes,
  exercise_name,
  sets,
  reps,
  weight,
  created_at,
  updated_at
)
select
  gen_random_uuid() as id,
  workout_name,
  session_date,
  session_notes,
  exercise_name,
  count(*) as sets,                         -- Count of individual sets becomes "sets" count
  max(reps) as reps,                        -- Take max reps (usually same across sets)
  max(weight) as weight,                    -- Take max weight (usually same across sets)
  min(created_at) as created_at,            -- Earliest timestamp
  max(updated_at) as updated_at             -- Latest timestamp
from sessions
group by workout_name, session_date, session_notes, exercise_name
on conflict do nothing;

-- =====================================================
-- 3. CREATE INDEXES FOR SESSIONS_NEW TABLE
-- =====================================================

create index if not exists idx_sessions_new_id
  on sessions_new(id);

create index if not exists idx_sessions_new_workout_name
  on sessions_new(workout_name);

create index if not exists idx_sessions_new_date
  on sessions_new(session_date desc);

create index if not exists idx_sessions_new_exercise_name
  on sessions_new(exercise_name);

create index if not exists idx_sessions_new_workout_date
  on sessions_new(workout_name, session_date desc);

create index if not exists idx_sessions_new_exercise_date
  on sessions_new(exercise_name, session_date desc);

-- =====================================================
-- 4. CREATE UPDATE TRIGGER FOR SESSIONS_NEW TABLE
-- =====================================================

create or replace function update_sessions_new_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists update_sessions_new_updated_at on sessions_new;

create trigger update_sessions_new_updated_at
  before update on sessions_new
  for each row
  execute function update_sessions_new_updated_at();

-- =====================================================
-- 5. ENABLE RLS FOR SESSIONS_NEW TABLE
-- =====================================================

alter table sessions_new enable row level security;

drop policy if exists "Allow all for anon users" on sessions_new;

create policy "Allow all for anon users" on sessions_new
  for all using (true) with check (true);

-- =====================================================
-- 6. DROP OLD SESSIONS TABLE AND RENAME NEW ONE
-- =====================================================

drop table if exists sessions cascade;
alter table sessions_new rename to sessions;

-- =====================================================
-- 7. ADD COMMENT
-- =====================================================

comment on table sessions is 'Denormalized session table with one row per exercise per session. Each row represents "X sets of Y reps at Z weight". Allows multiple entries for same exercise on same date with different set/rep/weight combinations.';

comment on column sessions.sets is 'Number of sets performed for this exercise (e.g., 3)';
comment on column sessions.reps is 'Reps per set (e.g., 10)';
