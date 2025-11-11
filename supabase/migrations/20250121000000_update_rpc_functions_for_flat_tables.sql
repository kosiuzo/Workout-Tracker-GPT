-- =====================================================
-- Update RPC Functions for Flat Table Structure
-- =====================================================
-- Updates existing RPC functions to work with the new
-- workouts_flat and sessions_flat tables while maintaining
-- backward compatibility with the cron job that calls them
-- =====================================================

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
      w.id as workout_id,
      sf.exercise_name,
      sf.session_date,
      count(*) as total_sets,
      sum(sf.reps) as total_reps,
      sum(sf.weight * sf.reps) as total_volume,
      max(sf.weight) as max_weight,
      avg(sf.weight) as avg_weight
    from sessions_flat sf
    join workouts_flat wf on sf.workout_name = wf.workout_name
    join workouts w on w.name = wf.workout_name
    where sf.session_date = date_override
      and sf.exercise_name is not null
      and sf.reps is not null
      and sf.weight is not null
    group by w.id, sf.exercise_name, sf.session_date
  )
  insert into exercise_history (
    workout_id,
    exercise_name,
    date,
    total_sets,
    total_reps,
    total_volume,
    max_weight,
    avg_weight
  )
  select
    workout_id,
    exercise_name,
    session_date,
    total_sets,
    total_reps,
    total_volume,
    max_weight,
    avg_weight
  from aggregated_data
  on conflict (workout_id, exercise_name, date)
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

comment on function calc_exercise_history is 'Aggregates session_flat data into exercise_history for a specific date. Idempotent - can be run multiple times safely.';

-- =====================================================
-- 2. UPDATE GET_RECENT_PROGRESS
-- =====================================================
-- Enhanced to explicitly select all fields for clarity

create or replace function get_recent_progress(
  days_back int default 7,
  workout_uuid uuid default null
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
      wh.workout_id,
      w.name as workout_name,
      wh.date,
      wh.total_volume,
      wh.total_sets,
      wh.total_reps,
      wh.num_exercises,
      wh.created_at,
      wh.updated_at
    from workout_history wh
    join workouts w on w.id = wh.workout_id
    where wh.date >= current_date - days_back
      and (workout_uuid is null or wh.workout_id = workout_uuid)
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

comment on function get_recent_progress is 'Returns workout history for the last N days, optionally filtered by workout.';

-- =====================================================
-- 3. UPDATE GET_EXERCISE_PROGRESS
-- =====================================================
-- Enhanced to explicitly select all fields for clarity

create or replace function get_exercise_progress(
  exercise_name_param text,
  days_back int default 30,
  workout_uuid uuid default null
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
      eh.workout_id,
      w.name as workout_name,
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
    join workouts w on w.id = eh.workout_id
    where eh.exercise_name = exercise_name_param
      and eh.date >= current_date - days_back
      and (workout_uuid is null or eh.workout_id = workout_uuid)
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

comment on function get_exercise_progress is 'Returns history for a specific exercise over time.';

-- =====================================================
-- NOTE: calc_workout_history and calc_all_history
-- =====================================================
-- These functions require NO CHANGES because they:
-- 1. calc_workout_history aggregates from exercise_history (not from sessions)
-- 2. calc_all_history orchestrates both functions in sequence
-- Both will work correctly with the updated calc_exercise_history
