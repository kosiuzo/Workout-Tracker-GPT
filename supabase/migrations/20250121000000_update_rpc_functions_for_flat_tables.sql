-- =====================================================
-- Update RPC Functions for Flat Table Structure
-- =====================================================
-- Updates existing RPC functions to work with the new
-- workouts_flat and sessions_flat tables while maintaining
-- backward compatibility with the cron job that calls them
-- =====================================================

-- =====================================================
-- DROP OLD FUNCTION VERSIONS WITH DIFFERENT SIGNATURES
-- =====================================================
-- Need to drop old versions to avoid conflicts when recreating with new signatures

drop function if exists get_recent_progress(int, uuid) cascade;
drop function if exists get_exercise_progress(text, int, uuid) cascade;
drop function if exists calc_workout_history(date) cascade;

-- =====================================================
-- 1. UPDATE CALC_EXERCISE_HISTORY
-- =====================================================
-- Now aggregates from sessions_flat instead of old sessions table
-- Maintains same function signature for cron job compatibility

create or replace function calc_exercise_history(date_override date default current_date)
returns json as $$
declare
  v_rows_affected int;
  v_result json;
begin
  -- Aggregate sessions_flat into exercise_history for the specified date
  with aggregated_data as (
    select
      sf.workout_name,
      sf.exercise_name,
      sf.session_date,
      count(*) as total_sets,
      sum(sf.reps) as total_reps,
      sum(sf.weight * sf.reps) as total_volume,
      max(sf.weight) as max_weight,
      avg(sf.weight) as avg_weight
    from sessions_flat sf
    where sf.session_date = date_override
      and sf.exercise_name is not null
      and sf.reps is not null
      and sf.weight is not null
    group by sf.workout_name, sf.exercise_name, sf.session_date
  )
  insert into exercise_history (
    workout_name,
    exercise_name,
    date,
    total_sets,
    total_reps,
    total_volume,
    max_weight,
    avg_weight
  )
  select
    workout_name,
    exercise_name,
    session_date,
    total_sets,
    total_reps,
    total_volume,
    max_weight,
    avg_weight
  from aggregated_data
  on conflict (workout_name, exercise_name, date)
  do update set
    total_sets = excluded.total_sets,
    total_reps = excluded.total_reps,
    total_volume = excluded.total_volume,
    max_weight = excluded.max_weight,
    avg_weight = excluded.avg_weight,
    updated_at = now();

  get diagnostics v_rows_affected = row_count;

  return json_build_object(
    'success', true,
    'date', date_override,
    'rows_affected', v_rows_affected,
    'message', format('Processed %s exercise records for %s', v_rows_affected, date_override)
  );
end;
$$ language plpgsql security definer;

comment on function calc_exercise_history is 'Aggregates session_flat data into exercise_history for a specific date using workout_name. Idempotent - can be run multiple times safely.';

-- =====================================================
-- 2. UPDATE GET_RECENT_PROGRESS
-- =====================================================
-- Returns workout history using workout_name instead of workout_id

create or replace function get_recent_progress(
  days_back int default 7,
  workout_name_param text default null
)
returns json as $$
declare
  v_history json;
begin
  select json_agg(row_to_json(wh.*) order by wh.date desc)
  into v_history
  from (
    select
      wh.id,
      wh.workout_name,
      wh.date,
      wh.total_volume,
      wh.total_sets,
      wh.total_reps,
      wh.num_exercises,
      wh.created_at,
      wh.updated_at
    from workout_history wh
    where wh.date >= current_date - days_back
      and (workout_name_param is null or wh.workout_name = workout_name_param)
    order by wh.date desc
  ) wh;

  if v_history is null then
    return json_build_object(
      'success', false,
      'message', 'No workout history found for the specified period'
    );
  end if;

  return json_build_object(
    'success', true,
    'days_back', days_back,
    'history', v_history
  );
end;
$$ language plpgsql security definer;

comment on function get_recent_progress is 'Returns workout history for the last N days, optionally filtered by workout_name.';

-- =====================================================
-- 3. UPDATE GET_EXERCISE_PROGRESS
-- =====================================================
-- Returns exercise history using workout_name instead of workout_id
-- No longer requires join to workouts table

create or replace function get_exercise_progress(
  exercise_name_param text,
  days_back int default 30,
  workout_name_param text default null
)
returns json as $$
declare
  v_history json;
begin
  select json_agg(row_to_json(eh.*) order by eh.date desc)
  into v_history
  from (
    select
      eh.id,
      eh.workout_name,
      eh.exercise_name,
      eh.date,
      eh.total_sets,
      eh.total_reps,
      eh.total_volume,
      eh.max_weight,
      eh.avg_weight,
      eh.created_at,
      eh.updated_at
    from exercise_history eh
    where eh.exercise_name = exercise_name_param
      and eh.date >= current_date - days_back
      and (workout_name_param is null or eh.workout_name = workout_name_param)
    order by eh.date desc
  ) eh;

  if v_history is null then
    return json_build_object(
      'success', false,
      'message', format('No history found for exercise: %s', exercise_name_param)
    );
  end if;

  return json_build_object(
    'success', true,
    'exercise', exercise_name_param,
    'days_back', days_back,
    'history', v_history
  );
end;
$$ language plpgsql security definer;

comment on function get_exercise_progress is 'Returns history for a specific exercise over time, optionally filtered by workout_name.';

-- =====================================================
-- 4. UPDATE CALC_WORKOUT_HISTORY
-- =====================================================
-- Rolls up exercise_history into workout_history using workout_name

create or replace function calc_workout_history(date_override date default current_date)
returns json as $$
declare
  v_rows_affected int;
  v_result json;
begin
  -- Aggregate exercise_history into workout_history for the specified date
  with aggregated_data as (
    select
      eh.workout_name,
      eh.date,
      sum(eh.total_volume) as total_volume,
      sum(eh.total_sets) as total_sets,
      sum(eh.total_reps) as total_reps,
      count(distinct eh.exercise_name) as num_exercises
    from exercise_history eh
    where eh.date = date_override
    group by eh.workout_name, eh.date
  )
  insert into workout_history (
    workout_name,
    date,
    total_volume,
    total_sets,
    total_reps,
    num_exercises
  )
  select
    workout_name,
    date,
    total_volume,
    total_sets,
    total_reps,
    num_exercises
  from aggregated_data
  on conflict (workout_name, date)
  do update set
    total_volume = excluded.total_volume,
    total_sets = excluded.total_sets,
    total_reps = excluded.total_reps,
    num_exercises = excluded.num_exercises,
    updated_at = now();

  get diagnostics v_rows_affected = row_count;

  return json_build_object(
    'success', true,
    'date', date_override,
    'rows_affected', v_rows_affected,
    'message', format('Processed %s workout records for %s', v_rows_affected, date_override)
  );
end;
$$ language plpgsql security definer;

comment on function calc_workout_history is 'Rolls up exercise_history into workout_history for a specific date using workout_name. Run after calc_exercise_history.';

-- =====================================================
-- NOTE: calc_all_history
-- =====================================================
-- This function requires NO CHANGES because:
-- It orchestrates both calc_exercise_history and calc_workout_history in sequence
-- Both will work correctly with the updated versions above
