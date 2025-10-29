-- =====================================================
-- Workout Tracker GPT v1.0 - RPC Functions
-- =====================================================
-- Core RPC functions for workout management and
-- incremental history aggregation
-- =====================================================

-- =====================================================
-- 1. SET_ACTIVE_WORKOUT
-- =====================================================
-- Ensures only one workout plan is active at a time
-- Deactivates all other workouts before activating the target

create or replace function set_active_workout(workout_uuid uuid)
returns json as $$
declare
  v_workout_name text;
  v_result json;
begin
  -- Check if workout exists
  select name into v_workout_name
  from workouts
  where id = workout_uuid;

  if v_workout_name is null then
    return json_build_object(
      'success', false,
      'error', 'Workout not found',
      'workout_id', workout_uuid
    );
  end if;

  -- Deactivate all workouts
  update workouts set is_active = false where is_active = true;

  -- Activate the target workout
  update workouts set is_active = true where id = workout_uuid;

  return json_build_object(
    'success', true,
    'message', 'Workout activated successfully',
    'workout_id', workout_uuid,
    'workout_name', v_workout_name
  );
end;
$$ language plpgsql security definer;

comment on function set_active_workout is 'Activates a workout plan and deactivates all others. Returns success status and workout details.';

-- =====================================================
-- 2. CALC_EXERCISE_HISTORY
-- =====================================================
-- Aggregates exercise data for a specific date
-- Incremental load pattern - processes only the specified date
-- Uses UPSERT for idempotency

create or replace function calc_exercise_history(date_override date default current_date)
returns json as $$
declare
  v_rows_affected int;
  v_result json;
begin
  -- Aggregate sessions into exercise_history for the specified date
  with aggregated_data as (
    select
      s.workout_id,
      (entry->>'exercise')::text as exercise_name,
      s.date,
      count(*) as total_sets,
      sum((entry->>'reps')::int) as total_reps,
      sum((entry->>'weight')::int * (entry->>'reps')::int) as total_volume,
      max((entry->>'weight')::int) as max_weight,
      avg((entry->>'weight')::int) as avg_weight
    from sessions s,
         jsonb_array_elements(s.entries) as entry
    where s.date = date_override
      and entry->>'exercise' is not null
      and entry->>'reps' is not null
      and entry->>'weight' is not null
    group by s.workout_id, exercise_name, s.date
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
    date,
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

comment on function calc_exercise_history is 'Aggregates session data into exercise_history for a specific date. Idempotent - can be run multiple times safely.';

-- =====================================================
-- 3. CALC_WORKOUT_HISTORY
-- =====================================================
-- Rolls up exercise_history into workout_history for a specific date
-- Must be run after calc_exercise_history

create or replace function calc_workout_history(date_override date default current_date)
returns json as $$
declare
  v_rows_affected int;
  v_result json;
begin
  -- Aggregate exercise_history into workout_history for the specified date
  with aggregated_data as (
    select
      eh.workout_id,
      eh.date,
      sum(eh.total_volume) as total_volume,
      sum(eh.total_sets) as total_sets,
      sum(eh.total_reps) as total_reps,
      count(distinct eh.exercise_name) as num_exercises
    from exercise_history eh
    where eh.date = date_override
    group by eh.workout_id, eh.date
  )
  insert into workout_history (
    workout_id,
    date,
    total_volume,
    total_sets,
    total_reps,
    num_exercises
  )
  select
    workout_id,
    date,
    total_volume,
    total_sets,
    total_reps,
    num_exercises
  from aggregated_data
  on conflict (workout_id, date)
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

comment on function calc_workout_history is 'Rolls up exercise_history into workout_history for a specific date. Run after calc_exercise_history.';

-- =====================================================
-- 4. CALC_ALL_HISTORY
-- =====================================================
-- Convenience function to run both aggregations in sequence
-- Ensures data consistency in a single transaction

create or replace function calc_all_history(date_override date default current_date)
returns json as $$
declare
  v_exercise_result json;
  v_workout_result json;
  v_final_result json;
begin
  -- Run exercise aggregation first
  select calc_exercise_history(date_override) into v_exercise_result;

  -- Then run workout aggregation
  select calc_workout_history(date_override) into v_workout_result;

  -- Combine results
  v_final_result := json_build_object(
    'success', true,
    'date', date_override,
    'exercise_history', v_exercise_result,
    'workout_history', v_workout_result,
    'message', format('Successfully aggregated all history for %s', date_override)
  );

  return v_final_result;
end;
$$ language plpgsql security definer;

comment on function calc_all_history is 'Runs both calc_exercise_history and calc_workout_history in a single transaction for a specific date.';

-- =====================================================
-- 5. GET_ACTIVE_WORKOUT
-- =====================================================
-- Convenience function to retrieve the currently active workout
-- Returns full workout details including all days

create or replace function get_active_workout()
returns json as $$
declare
  v_workout json;
begin
  select to_json(w.*)
  into v_workout
  from workouts w
  where w.is_active = true
  limit 1;

  if v_workout is null then
    return json_build_object(
      'success', false,
      'message', 'No active workout found'
    );
  end if;

  return json_build_object(
    'success', true,
    'workout', v_workout
  );
end;
$$ language plpgsql security definer;

comment on function get_active_workout is 'Returns the currently active workout with all details.';

-- =====================================================
-- 6. GET_WORKOUT_FOR_DAY
-- =====================================================
-- Returns the workout plan for a specific day of the week
-- Uses the active workout by default

create or replace function get_workout_for_day(
  day_name text,
  workout_uuid uuid default null
)
returns json as $$
declare
  v_workout_id uuid;
  v_workout_name text;
  v_exercises json;
begin
  -- If no workout_id provided, use active workout
  if workout_uuid is null then
    select id, name into v_workout_id, v_workout_name
    from workouts
    where is_active = true
    limit 1;

    if v_workout_id is null then
      return json_build_object(
        'success', false,
        'message', 'No active workout found'
      );
    end if;
  else
    select id, name into v_workout_id, v_workout_name
    from workouts
    where id = workout_uuid;

    if v_workout_id is null then
      return json_build_object(
        'success', false,
        'message', 'Workout not found'
      );
    end if;
  end if;

  -- Get exercises for the specified day
  select days->lower(day_name) into v_exercises
  from workouts
  where id = v_workout_id;

  if v_exercises is null then
    return json_build_object(
      'success', false,
      'workout_id', v_workout_id,
      'workout_name', v_workout_name,
      'day', day_name,
      'message', format('No exercises found for %s', day_name)
    );
  end if;

  return json_build_object(
    'success', true,
    'workout_id', v_workout_id,
    'workout_name', v_workout_name,
    'day', day_name,
    'exercises', v_exercises
  );
end;
$$ language plpgsql security definer;

comment on function get_workout_for_day is 'Returns the workout plan for a specific day from the active workout (or specified workout).';

-- =====================================================
-- 7. GET_RECENT_PROGRESS
-- =====================================================
-- Returns aggregated workout history for the last N days
-- Useful for progress summaries

create or replace function get_recent_progress(
  days_back int default 7,
  workout_uuid uuid default null
)
returns json as $$
declare
  v_history json;
begin
  select json_agg(row_to_json(wh.*))
  into v_history
  from (
    select
      wh.*,
      w.name as workout_name
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
-- 8. GET_EXERCISE_PROGRESS
-- =====================================================
-- Returns history for a specific exercise
-- Shows progression over time

create or replace function get_exercise_progress(
  exercise_name_param text,
  days_back int default 30,
  workout_uuid uuid default null
)
returns json as $$
declare
  v_history json;
begin
  select json_agg(row_to_json(eh.*))
  into v_history
  from (
    select
      eh.*,
      w.name as workout_name
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
