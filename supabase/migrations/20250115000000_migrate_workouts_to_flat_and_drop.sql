-- =====================================================
-- Migrate Workouts Table to Workouts_Flat and Drop
-- =====================================================
-- This migration:
-- 1. Migrates any remaining data from workouts to workouts_flat
-- 2. Updates functions that reference workouts table
-- 3. Drops triggers and dependencies on workouts table
-- 4. Drops the workouts table
--
-- ⚠️  VERIFY data migration before dropping workouts table
-- =====================================================

-- =====================================================
-- PHASE 1: MIGRATE DATA FROM WORKOUTS TO WORKOUTS_FLAT
-- =====================================================
-- Extract data from JSONB days column and insert into workouts_flat
-- Uses ON CONFLICT to avoid duplicates if already migrated

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
  'Workouts in source table:' as check_type,
  count(distinct name)::text as result
from workouts
union all
select
  'Workouts in flat table:' as check_type,
  count(distinct workout_name)::text as result
from workouts_flat
union all
select
  'Total exercises in flat table:' as check_type,
  count(*)::text as result
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
-- PHASE 2: UPDATE FUNCTIONS THAT REFERENCE WORKOUTS
-- =====================================================
-- Update create_workout_from_json to remove workouts table dependency

create or replace function create_workout_from_json(workout_json jsonb)
returns json as $$
declare
  v_workout_name text;
  v_workout_description text;
  v_is_active boolean;
  v_days jsonb;
  v_day_obj jsonb;
  v_exercises jsonb;
  v_exercise_obj jsonb;
  v_day_name text;
  v_day_notes text;
  v_exercise_order int;
  v_exercise_name text;
  v_sets int;
  v_reps int;
  v_weight numeric;
  v_superset_group text;
  v_exercise_notes text;
  v_rows_inserted int := 0;
begin
  -- Extract workout metadata
  v_workout_name := workout_json->>'workout_name';
  v_workout_description := workout_json->>'workout_description';
  v_is_active := coalesce((workout_json->>'is_active')::boolean, false);
  v_days := workout_json->'days';

  -- Validate required fields
  if v_workout_name is null or trim(v_workout_name) = '' then
    return json_build_object(
      'success', false,
      'error', 'workout_name is required'
    );
  end if;

  if v_days is null or jsonb_typeof(v_days) != 'array' then
    return json_build_object(
      'success', false,
      'error', 'days must be a JSON array'
    );
  end if;

  -- Check if workout already exists
  if exists (select 1 from workouts_flat where workout_name = v_workout_name) then
    return json_build_object(
      'success', false,
      'error', 'Workout already exists',
      'workout_name', v_workout_name
    );
  end if;

  -- If marking as active, first deactivate any existing active workouts
  if v_is_active then
    update workouts_flat set workout_is_active = false where workout_is_active = true;
  end if;

  -- Process each day
  for v_day_obj in select jsonb_array_elements(v_days)
  loop
    v_day_name := lower(trim(v_day_obj->>'day_name'));
    v_day_notes := v_day_obj->>'day_notes';
    v_exercises := v_day_obj->'exercises';

    -- Validate day_name and exercises
    if v_day_name is null or trim(v_day_name) = '' then
      continue; -- Skip if no day_name
    end if;

    if v_exercises is null or jsonb_typeof(v_exercises) != 'array' then
      continue; -- Skip if no exercises array
    end if;

    -- Process each exercise for this day
    v_exercise_order := 0;
    for v_exercise_obj in select jsonb_array_elements(v_exercises)
    loop
      v_exercise_name := trim(v_exercise_obj->>'exercise_name');
      v_sets := (v_exercise_obj->>'sets')::int;
      v_reps := (v_exercise_obj->>'reps')::int;
      v_weight := (v_exercise_obj->>'weight')::numeric;
      v_superset_group := v_exercise_obj->>'superset_group';
      v_exercise_notes := v_exercise_obj->>'exercise_notes';

      -- Validate required exercise fields
      if v_exercise_name is not null and trim(v_exercise_name) != '' and v_sets is not null and v_reps is not null then
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
          exercise_notes
        )
        values (
          v_workout_name,
          v_workout_description,
          v_is_active,
          v_day_name,
          v_day_notes,
          v_exercise_order,
          v_exercise_name,
          v_sets,
          v_reps,
          coalesce(v_weight, 0),
          v_superset_group,
          v_exercise_notes
        );

        v_rows_inserted := v_rows_inserted + 1;
        v_exercise_order := v_exercise_order + 1;
      end if;
    end loop;
  end loop;

  if v_rows_inserted = 0 then
    return json_build_object(
      'success', false,
      'error', 'No valid exercises found in JSON',
      'workout_name', v_workout_name
    );
  end if;

  return json_build_object(
    'success', true,
    'workout_name', v_workout_name,
    'workout_description', v_workout_description,
    'is_active', v_is_active,
    'rows_inserted', v_rows_inserted,
    'message', format('Created workout "%s" with %s exercises', v_workout_name, v_rows_inserted)
  );
end;
$$ language plpgsql security definer;

comment on function create_workout_from_json is 'Creates a complete workout from JSON structure. Accepts JSON with workout_name, workout_description, is_active, and days array with exercises. Automatically populates workouts_flat table. No longer uses workouts table.';

-- =====================================================
-- PHASE 3: DROP TRIGGERS AND DEPENDENCIES
-- =====================================================

-- Drop trigger on workouts table
drop trigger if exists update_workouts_updated_at on workouts;

-- =====================================================
-- PHASE 4: DROP WORKOUTS TABLE
-- =====================================================
-- ⚠️  ONLY RUN AFTER VERIFYING PHASE 1 & 2
-- This is irreversible - ensure all data is in workouts_flat
-- =====================================================

select '=== DROPPING WORKOUTS TABLE ===' as info;

-- Drop the workouts table
drop table if exists workouts cascade;

-- =====================================================
-- VERIFY PHASE 4: CLEANUP
-- =====================================================

select '=== FINAL STATUS ===' as info;

select
  'workouts' as table_name,
  case when exists (select from information_schema.tables where table_name = 'workouts') then '⚠️ EXISTS' else '✅ DROPPED' end as status
union all
select
  'workouts_flat' as table_name,
  case when exists (select from information_schema.tables where table_name = 'workouts_flat') then '✅ EXISTS' else '❌ MISSING' end as status;

select '=== MIGRATION COMPLETE ===' as info;
select 'Workouts table has been migrated to workouts_flat and dropped.' as message;

