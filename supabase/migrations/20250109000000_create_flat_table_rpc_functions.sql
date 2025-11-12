-- =====================================================
-- Flat Table RPC Functions
-- =====================================================
-- RPC functions for working with workouts_flat and
-- sessions_flat tables to simplify workout logging
-- =====================================================

-- =====================================================
-- 1. GET_TODAYS_EXERCISES_FLAT
-- =====================================================
-- Get today's workout exercises from the flattened table
-- Returns structured data ready for logging

create or replace function get_todays_exercises_flat()
returns json as $$
declare
  v_current_day text;
  v_workout_name text;
  v_exercises json;
begin
  -- Get the current day of the week in lowercase using Eastern Time
  v_current_day := lower(trim(to_char(current_timestamp at time zone 'America/New_York', 'Day')));

  -- Get active workout name
  select workout_name into v_workout_name
  from workouts_flat
  where workout_is_active = true
  limit 1;

  if v_workout_name is null then
    return json_build_object(
      'success', false,
      'message', 'No active workout found',
      'current_day', v_current_day
    );
  end if;

  -- Get exercises for today from flat table
  select json_agg(
    json_build_object(
      'exercise_order', exercise_order,
      'exercise_name', exercise_name,
      'sets', sets,
      'reps', reps,
      'weight', weight,
      'superset_group', superset_group,
      'notes', exercise_notes,
      'day_notes', day_notes
    ) order by exercise_order
  )
  into v_exercises
  from workouts_flat
  where workout_name = v_workout_name
    and day_name = v_current_day;

  if v_exercises is null then
    return json_build_object(
      'success', false,
      'workout_name', v_workout_name,
      'current_day', v_current_day,
      'message', format('No exercises scheduled for %s', v_current_day)
    );
  end if;

  return json_build_object(
    'success', true,
    'workout_name', v_workout_name,
    'current_day', v_current_day,
    'exercises', v_exercises
  );
end;
$$ language plpgsql security definer;

comment on function get_todays_exercises_flat is 'Returns today''s workout exercises from workouts_flat table';

-- =====================================================
-- 2. GET_EXERCISES_FOR_DAY_FLAT
-- =====================================================
-- Get exercises for a specific day from the flattened table

create or replace function get_exercises_for_day_flat(
  day_name_param text,
  workout_name_param text default null
)
returns json as $$
declare
  v_workout_name text;
  v_exercises json;
begin
  -- If no workout_name provided, use active workout
  if workout_name_param is null then
    select workout_name into v_workout_name
    from workouts_flat
    where workout_is_active = true
    limit 1;
  else
    select workout_name into v_workout_name
    from workouts_flat
    where workout_name = workout_name_param
    limit 1;
  end if;

  if v_workout_name is null then
    return json_build_object(
      'success', false,
      'message', 'Workout not found'
    );
  end if;

  -- Get exercises for specified day
  select json_agg(
    json_build_object(
      'exercise_order', exercise_order,
      'exercise_name', exercise_name,
      'sets', sets,
      'reps', reps,
      'weight', weight,
      'superset_group', superset_group,
      'notes', exercise_notes,
      'day_notes', day_notes
    ) order by exercise_order
  )
  into v_exercises
  from workouts_flat
  where workout_name = v_workout_name
    and day_name = lower(day_name_param);

  if v_exercises is null then
    return json_build_object(
      'success', false,
      'workout_name', v_workout_name,
      'day', day_name_param,
      'message', format('No exercises found for %s', day_name_param)
    );
  end if;

  return json_build_object(
    'success', true,
    'workout_name', v_workout_name,
    'day', lower(day_name_param),
    'exercises', v_exercises
  );
end;
$$ language plpgsql security definer;

comment on function get_exercises_for_day_flat is 'Returns exercises for a specific day from workouts_flat table';

-- =====================================================
-- 4. LOG_SET
-- =====================================================
-- Log a single set to an existing session
-- Directly inserts into sessions_flat table

create or replace function log_set(
  workout_name_param text,
  session_date_param date,
  exercise_name_param text,
  set_number_param int,
  reps_param int,
  weight_param numeric,
  session_notes_param text default null
)
returns json as $$
declare
  v_result record;
begin
  -- Validate inputs
  if exercise_name_param is null or trim(exercise_name_param) = '' then
    return json_build_object(
      'success', false,
      'message', 'Exercise name is required'
    );
  end if;

  if set_number_param is null or set_number_param < 1 then
    return json_build_object(
      'success', false,
      'message', 'Set number must be a positive integer'
    );
  end if;

  if reps_param is null or reps_param < 0 then
    return json_build_object(
      'success', false,
      'message', 'Reps must be a non-negative integer'
    );
  end if;

  if weight_param is null or weight_param < 0 then
    return json_build_object(
      'success', false,
      'message', 'Weight must be a non-negative number'
    );
  end if;

  -- Insert or replace set in sessions_flat
  insert into sessions_flat (workout_name, session_date, exercise_name, set_number, reps, weight, session_notes)
  values (workout_name_param, session_date_param, exercise_name_param, set_number_param, reps_param, weight_param, session_notes_param)
  on conflict (workout_name, session_date, exercise_name, set_number) do update
  set reps = reps_param, weight = weight_param, session_notes = session_notes_param
  returning * into v_result;

  return json_build_object(
    'success', true,
    'message', 'Set logged successfully',
    'workout_name', v_result.workout_name,
    'session_date', v_result.session_date,
    'exercise', v_result.exercise_name,
    'set', v_result.set_number,
    'reps', v_result.reps,
    'weight', v_result.weight
  );
end;
$$ language plpgsql security definer;

comment on function log_set is 'Logs a single set to a session_flat. If a set with the same exercise and set number exists, it will be replaced.';

-- =====================================================
-- 5. LOG_MULTIPLE_SETS
-- =====================================================
-- Log multiple sets at once for efficiency

create or replace function log_multiple_sets(
  workout_name_param text,
  session_date_param date,
  sets_data jsonb,
  session_notes_param text default null
)
returns json as $$
declare
  v_count int := 0;
  v_set_entry jsonb;
  v_result json;
begin
  -- Validate sets_data is an array
  if jsonb_typeof(sets_data) != 'array' then
    return json_build_object(
      'success', false,
      'message', 'sets_data must be a JSON array'
    );
  end if;

  -- Log each set
  for v_set_entry in select * from jsonb_array_elements(sets_data)
  loop
    select log_set(
      workout_name_param,
      session_date_param,
      v_set_entry->>'exercise',
      (v_set_entry->>'set')::int,
      (v_set_entry->>'reps')::int,
      (v_set_entry->>'weight')::numeric,
      session_notes_param
    ) into v_result;

    if (v_result->>'success')::boolean then
      v_count := v_count + 1;
    end if;
  end loop;

  return json_build_object(
    'success', true,
    'message', format('Logged %s sets successfully', v_count),
    'workout_name', workout_name_param,
    'session_date', session_date_param,
    'sets_logged', v_count
  );
end;
$$ language plpgsql security definer;

comment on function log_multiple_sets is 'Logs multiple sets at once. Expects JSON array of objects with exercise, set, reps, and weight fields.';

-- =====================================================
-- 6. GET_SESSION_SETS_FLAT
-- =====================================================
-- Get all sets from a session using the flat table

create or replace function get_session_sets_flat(
  workout_name_param text,
  session_date_param date
)
returns json as $$
declare
  v_sets json;
  v_session_notes text;
begin
  -- Get session notes
  select session_notes into v_session_notes
  from sessions_flat
  where workout_name = workout_name_param
    and session_date = session_date_param
  limit 1;

  if v_session_notes is null and not exists(
    select 1 from sessions_flat
    where workout_name = workout_name_param
      and session_date = session_date_param
  ) then
    return json_build_object(
      'success', false,
      'message', 'Session not found',
      'workout_name', workout_name_param,
      'session_date', session_date_param
    );
  end if;

  -- Get sets from flat table
  select json_agg(
    json_build_object(
      'exercise_name', exercise_name,
      'set_number', set_number,
      'reps', reps,
      'weight', weight
    ) order by exercise_name, set_number
  )
  into v_sets
  from sessions_flat
  where workout_name = workout_name_param
    and session_date = session_date_param;

  return json_build_object(
    'success', true,
    'workout_name', workout_name_param,
    'session_date', session_date_param,
    'session_notes', v_session_notes,
    'sets', coalesce(v_sets, '[]'::json)
  );
end;
$$ language plpgsql security definer;

comment on function get_session_sets_flat is 'Returns all sets for a session from the sessions_flat table';

-- =====================================================
-- 7. GET_TODAYS_SESSION
-- =====================================================
-- Get today's session with all sets

create or replace function get_todays_session()
returns json as $$
declare
  v_workout_name text;
  v_current_date date;
begin
  -- Get current date in Eastern Time
  v_current_date := (current_timestamp at time zone 'America/New_York')::date;

  -- Find active workout
  select workout_name into v_workout_name
  from workouts_flat
  where workout_is_active = true
  limit 1;

  if v_workout_name is null then
    return json_build_object(
      'success', false,
      'message', 'No active workout found',
      'date', v_current_date
    );
  end if;

  -- Return session details
  return get_session_sets_flat(v_workout_name, v_current_date);
end;
$$ language plpgsql security definer;

comment on function get_todays_session is 'Returns today''s workout session with all sets from the active workout';

-- =====================================================
-- 8. UPDATE_SET
-- =====================================================
-- Update a specific set in a session

create or replace function update_set(
  workout_name_param text,
  session_date_param date,
  exercise_name_param text,
  set_number_param int,
  reps_param int default null,
  weight_param numeric default null
)
returns json as $$
declare
  v_current_reps int;
  v_current_weight numeric;
begin
  -- Get current values
  select reps, weight into v_current_reps, v_current_weight
  from sessions_flat
  where workout_name = workout_name_param
    and session_date = session_date_param
    and exercise_name = exercise_name_param
    and set_number = set_number_param;

  if v_current_reps is null then
    return json_build_object(
      'success', false,
      'message', 'Set not found',
      'exercise', exercise_name_param,
      'set', set_number_param
    );
  end if;

  -- Update the set with provided values or keep current
  update sessions_flat
  set
    reps = coalesce(reps_param, v_current_reps),
    weight = coalesce(weight_param, v_current_weight)
  where workout_name = workout_name_param
    and session_date = session_date_param
    and exercise_name = exercise_name_param
    and set_number = set_number_param;

  return json_build_object(
    'success', true,
    'message', 'Set updated successfully',
    'workout_name', workout_name_param,
    'session_date', session_date_param,
    'exercise', exercise_name_param,
    'set', set_number_param,
    'reps', coalesce(reps_param, v_current_reps),
    'weight', coalesce(weight_param, v_current_weight)
  );
end;
$$ language plpgsql security definer;

comment on function update_set is 'Updates a specific set in a session. Only provided parameters will be updated.';

-- =====================================================
-- 9. DELETE_SET
-- =====================================================
-- Delete a specific set from a session

create or replace function delete_set(
  workout_name_param text,
  session_date_param date,
  exercise_name_param text,
  set_number_param int
)
returns json as $$
declare
  v_rows_deleted int;
begin
  -- Delete the matching set
  delete from sessions_flat
  where workout_name = workout_name_param
    and session_date = session_date_param
    and exercise_name = exercise_name_param
    and set_number = set_number_param;

  get diagnostics v_rows_deleted = row_count;

  if v_rows_deleted = 0 then
    return json_build_object(
      'success', false,
      'message', 'Set not found',
      'exercise', exercise_name_param,
      'set', set_number_param
    );
  end if;

  return json_build_object(
    'success', true,
    'message', 'Set deleted successfully',
    'workout_name', workout_name_param,
    'session_date', session_date_param,
    'exercise', exercise_name_param,
    'set', set_number_param
  );
end;
$$ language plpgsql security definer;

comment on function delete_set is 'Deletes a specific set from a session';

-- =====================================================
-- 9. UPDATE_SESSION_NOTES
-- =====================================================
-- Update session notes for a workout on a specific date

create or replace function update_session_notes(
  workout_name_param text,
  session_date_param date,
  session_notes_param text
)
returns json as $$
declare
  v_rows_updated int;
begin
  -- Update all rows for this session with the notes
  update sessions_flat
  set session_notes = session_notes_param
  where workout_name = workout_name_param
    and session_date = session_date_param;

  get diagnostics v_rows_updated = row_count;

  if v_rows_updated = 0 then
    return json_build_object(
      'success', false,
      'message', 'No session found to update notes',
      'workout_name', workout_name_param,
      'session_date', session_date_param
    );
  end if;

  return json_build_object(
    'success', true,
    'message', 'Session notes updated',
    'workout_name', workout_name_param,
    'session_date', session_date_param,
    'notes', session_notes_param,
    'rows_updated', v_rows_updated
  );
end;
$$ language plpgsql security definer;

comment on function update_session_notes is 'Updates session notes for a workout on a specific date';

-- =====================================================
-- 10. GET_EXERCISE_HISTORY_FLAT
-- =====================================================
-- Get history for a specific exercise from sessions_flat

create or replace function get_exercise_history_flat(
  exercise_name_param text,
  days_back int default 30,
  workout_name_param text default null
)
returns json as $$
declare
  v_history json;
  v_summary json;
begin
  -- Get detailed history from flat table
  select json_agg(
    json_build_object(
      'date', session_date,
      'workout', workout_name,
      'set_number', set_number,
      'reps', reps,
      'weight', weight,
      'volume', reps * weight
    ) order by session_date desc, set_number
  )
  into v_history
  from sessions_flat
  where exercise_name = exercise_name_param
    and session_date >= current_date - days_back
    and (workout_name_param is null or workout_name = workout_name_param);

  if v_history is null then
    return json_build_object(
      'success', false,
      'message', format('No history found for exercise: %s', exercise_name_param),
      'exercise', exercise_name_param
    );
  end if;

  -- Get summary statistics by date
  select json_agg(
    json_build_object(
      'date', summary_data.session_date,
      'total_sets', summary_data.total_sets,
      'total_reps', summary_data.total_reps,
      'total_volume', summary_data.total_volume,
      'max_weight', summary_data.max_weight,
      'avg_weight', summary_data.avg_weight
    ) order by summary_data.session_date desc
  )
  into v_summary
  from (
    select
      session_date,
      count(*) as total_sets,
      sum(reps) as total_reps,
      sum(reps * weight) as total_volume,
      max(weight) as max_weight,
      round(avg(weight)::numeric, 2) as avg_weight
    from sessions_flat
    where exercise_name = exercise_name_param
      and session_date >= current_date - days_back
      and (workout_name_param is null or workout_name = workout_name_param)
    group by session_date
  ) summary_data;

  return json_build_object(
    'success', true,
    'exercise', exercise_name_param,
    'days_back', days_back,
    'detailed_history', v_history,
    'summary', v_summary
  );
end;
$$ language plpgsql security definer;

comment on function get_exercise_history_flat is 'Returns detailed history for a specific exercise from sessions_flat table';

-- =====================================================
-- 11. GET_WORKOUT_SUMMARY_FLAT
-- =====================================================
-- Get summary of a workout from sessions_flat

create or replace function get_workout_summary_flat(
  workout_name_param text,
  session_date_param date
)
returns json as $$
declare
  v_session_notes text;
  v_summary json;
begin
  -- Get session notes
  select session_notes into v_session_notes
  from sessions_flat
  where workout_name = workout_name_param
    and session_date = session_date_param
  limit 1;

  if v_session_notes is null and not exists(
    select 1 from sessions_flat
    where workout_name = workout_name_param
      and session_date = session_date_param
  ) then
    return json_build_object(
      'success', false,
      'message', 'Session not found',
      'workout_name', workout_name_param,
      'session_date', session_date_param
    );
  end if;

  -- Get summary by exercise
  select json_agg(
    json_build_object(
      'exercise_name', exercise_name,
      'total_sets', total_sets,
      'total_reps', total_reps,
      'total_volume', total_volume,
      'max_weight', max_weight,
      'avg_weight', avg_weight
    ) order by first_created
  )
  into v_summary
  from (
    select
      exercise_name,
      count(*) as total_sets,
      sum(reps) as total_reps,
      sum(reps * weight) as total_volume,
      max(weight) as max_weight,
      round(avg(weight)::numeric, 2) as avg_weight,
      min(created_at) as first_created
    from sessions_flat
    where workout_name = workout_name_param
      and session_date = session_date_param
    group by exercise_name
  ) summary_data;

  return json_build_object(
    'success', true,
    'workout_name', workout_name_param,
    'session_date', session_date_param,
    'session_notes', v_session_notes,
    'summary', coalesce(v_summary, '[]'::json)
  );
end;
$$ language plpgsql security definer;

comment on function get_workout_summary_flat is 'Returns summary statistics for a workout session grouped by exercise';
