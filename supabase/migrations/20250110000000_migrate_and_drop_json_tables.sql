-- =====================================================
-- Migrate and Drop All JSON-based Tables
-- =====================================================
-- Comprehensive migration from JSON-based workouts and sessions
-- to normalized flat table structures
--
-- PHASE 1: Migrate workouts data
-- PHASE 2: Migrate sessions data
-- PHASE 3: Drop old workouts and sessions tables
--
-- ⚠️  VERIFY each phase before proceeding to next
-- =====================================================

-- =====================================================
-- PHASE 1: MIGRATE WORKOUTS DATA
-- =====================================================
-- Extract data from JSONB days column and insert into workouts_flat

insert into workouts_flat (
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
  w.name as workout_name,
  w.description as workout_description,
  w.is_active as workout_is_active,
  day_entry.key as day_name,
  day_entry.value->>'day_notes' as day_notes,
  exercise_idx - 1 as exercise_order,
  exercise->>'exercise' as exercise_name,
  (exercise->>'sets')::int as sets,
  (exercise->>'reps')::int as reps,
  (exercise->>'weight')::int as weight,
  exercise->>'superset_group' as superset_group,
  exercise->>'notes' as exercise_notes,
  w.created_at,
  w.updated_at
from workouts w,
  jsonb_each(w.days) as day_entry,
  jsonb_array_elements(day_entry.value->'exercises') with ordinality as exercises(exercise, exercise_idx)
where jsonb_typeof(day_entry.value) = 'object'
  and exercise->>'exercise' is not null
on conflict (workout_name, day_name, exercise_order) do nothing;

-- =====================================================
-- VERIFY PHASE 1: WORKOUTS MIGRATION
-- =====================================================

select '=== WORKOUTS MIGRATION STATISTICS ===' as info;

select
  'Workouts migrated:' as check_type,
  count(distinct workout_name)::text as result
from workouts_flat
union all
select
  'Total exercises:' as check_type,
  count(*)::text as result
from workouts_flat
union all
select
  'Days covered:' as check_type,
  count(distinct day_name)::text as result
from workouts_flat;

-- =====================================================
-- SANITY CHECK: WORKOUTS
-- =====================================================
-- ⚠️  Verify all counts match before proceeding!

select '=== WORKOUTS SANITY CHECK ===' as info;

with source_counts as (
  select
    w.name as workout_name,
    count(*) as exercise_count
  from workouts w,
    jsonb_each(w.days) as day_entry,
    jsonb_array_elements(day_entry.value->'exercises') as exercise
  where jsonb_typeof(day_entry.value) = 'object'
    and exercise->>'exercise' is not null
  group by w.name
),
flat_counts as (
  select
    workout_name,
    count(*) as exercise_count
  from workouts_flat
  group by workout_name
)
select
  coalesce(s.workout_name, f.workout_name) as workout_name,
  coalesce(s.exercise_count, 0) as source_count,
  coalesce(f.exercise_count, 0) as flat_count,
  case
    when s.exercise_count = f.exercise_count then '✅ OK'
    else '❌ MISMATCH - DO NOT PROCEED'
  end as status
from source_counts s
full outer join flat_counts f on s.workout_name = f.workout_name
order by workout_name;

-- =====================================================
-- PHASE 2: MIGRATE SESSIONS DATA
-- =====================================================
-- Extract data from JSONB entries column and insert into sessions_flat

insert into sessions_flat (
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
  w.name as workout_name,
  s.date as session_date,
  s.notes as session_notes,
  entry->>'exercise' as exercise_name,
  (entry->>'set')::int as set_number,
  (entry->>'reps')::int as reps,
  (entry->>'weight')::numeric as weight,
  s.created_at,
  s.updated_at
from sessions s
join workouts w on s.workout_id = w.id,
  jsonb_array_elements(s.entries) as entry
where entry->>'exercise' is not null
  and entry->>'set' is not null
  and entry->>'reps' is not null
  and entry->>'weight' is not null
on conflict (workout_name, session_date, exercise_name, set_number) do nothing;

-- =====================================================
-- VERIFY PHASE 2: SESSIONS MIGRATION
-- =====================================================

select '=== SESSIONS MIGRATION STATISTICS ===' as info;

select
  'Sessions migrated:' as check_type,
  count(distinct (workout_name, session_date))::text as result
from sessions_flat
union all
select
  'Total sets logged:' as check_type,
  count(*)::text as result
from sessions_flat
union all
select
  'Exercises tracked:' as check_type,
  count(distinct exercise_name)::text as result
from sessions_flat;

-- =====================================================
-- SANITY CHECK: SESSIONS
-- =====================================================
-- ⚠️  Verify all counts match before proceeding!

select '=== SESSIONS SANITY CHECK ===' as info;

with source_counts as (
  select
    w.name as workout_name,
    s.date as session_date,
    count(*) as set_count
  from sessions s
  join workouts w on s.workout_id = w.id,
    jsonb_array_elements(s.entries) as entry
  where entry->>'exercise' is not null
    and entry->>'set' is not null
    and entry->>'reps' is not null
    and entry->>'weight' is not null
  group by w.name, s.date
),
flat_counts as (
  select
    workout_name,
    session_date,
    count(*) as set_count
  from sessions_flat
  group by workout_name, session_date
)
select
  coalesce(s.workout_name, f.workout_name) as workout_name,
  coalesce(s.session_date, f.session_date) as session_date,
  coalesce(s.set_count, 0) as source_count,
  coalesce(f.set_count, 0) as flat_count,
  case
    when s.set_count = f.set_count then '✅ OK'
    else '❌ MISMATCH - DO NOT PROCEED'
  end as status
from source_counts s
full outer join flat_counts f
  on s.workout_name = f.workout_name
  and s.session_date = f.session_date
order by workout_name, session_date;

-- =====================================================
-- PHASE 3: DROP OLD JSON-BASED TABLES
-- =====================================================
-- ⚠️  ONLY RUN AFTER VERIFYING PHASE 1 & 2
-- This is irreversible - ensure all data is in flat tables
-- =====================================================

select '=== DROPPING OLD TABLES ===' as info;

-- Remove triggers and functions from old tables
drop trigger if exists update_workouts_updated_at on workouts;
drop trigger if exists sync_sessions_flat_trigger on sessions;
drop trigger if exists update_sessions_updated_at on sessions;
drop function if exists sync_workouts_flat_on_change();
drop function if exists sync_workouts_flat();
drop function if exists sync_sessions_flat_on_change();
drop function if exists sync_sessions_flat();

-- Drop dependent tables that reference workouts
drop table if exists workout_history cascade;
drop table if exists exercise_history cascade;

-- Drop the original sessions table (references workouts)
drop table if exists sessions cascade;

-- NOTE: Keep the original workouts table for referential integrity with history tables
-- do NOT drop workouts table

-- =====================================================
-- VERIFY PHASE 3: CLEANUP
-- =====================================================

select '=== FINAL STATUS ===' as info;

select
  'workouts' as table_name,
  case when exists (select from information_schema.tables where table_name = 'workouts') then '⚠️ EXISTS' else '✅ DROPPED' end as status
union all
select
  'sessions' as table_name,
  case when exists (select from information_schema.tables where table_name = 'sessions') then '⚠️ EXISTS' else '✅ DROPPED' end as status
union all
select
  'exercise_history' as table_name,
  case when exists (select from information_schema.tables where table_name = 'exercise_history') then '⚠️ EXISTS' else '✅ DROPPED' end as status
union all
select
  'workout_history' as table_name,
  case when exists (select from information_schema.tables where table_name = 'workout_history') then '⚠️ EXISTS' else '✅ DROPPED' end as status
union all
select
  'workouts_flat' as table_name,
  case when exists (select from information_schema.tables where table_name = 'workouts_flat') then '✅ EXISTS' else '❌ MISSING' end as status
union all
select
  'sessions_flat' as table_name,
  case when exists (select from information_schema.tables where table_name = 'sessions_flat') then '✅ EXISTS' else '❌ MISSING' end as status;

select '=== MIGRATION COMPLETE ===' as info;
