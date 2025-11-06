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
  v_workout_id uuid;
  v_workout_name text;
  v_exercises json;
begin
  -- Get the current day of the week in lowercase using Eastern Time
  v_current_day := lower(trim(to_char(current_timestamp at time zone 'America/New_York', 'Day')));

  -- Get active workout
  select id, workout_name into v_workout_id, v_workout_name
  from workouts_flat
  where workout_is_active = true
  limit 1;

  if v_workout_id is null then
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
      'notes', exercise_notes
    ) order by exercise_order
  )
  into v_exercises
  from workouts_flat
  where workout_id = v_workout_id
    and day_name = v_current_day;

  if v_exercises is null then
    return json_build_object(
      'success', false,
      'workout_id', v_workout_id,
      'workout_name', v_workout_name,
      'current_day', v_current_day,
      'message', format('No exercises scheduled for %s', v_current_day)
    );
  end if;

  return json_build_object(
    'success', true,
    'workout_id', v_workout_id,
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
    select workout_id, workout_name into v_workout_id, v_workout_name
    from workouts_flat
    where workout_is_active = true
    limit 1;
  else
    select workout_id, workout_name into v_workout_id, v_workout_name
    from workouts_flat
    where workout_id = workout_uuid
    limit 1;
  end if;

  if v_workout_id is null then
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
      'notes', exercise_notes
    ) order by exercise_order
  )
  into v_exercises
  from workouts_flat
  where workout_id = v_workout_id
    and day_name = lower(day_name_param);

  if v_exercises is null then
    return json_build_object(
      'success', false,
      'workout_id', v_workout_id,
      'workout_name', v_workout_name,
      'day', day_name_param,
      'message', format('No exercises found for %s', day_name_param)
    );
  end if;

  return json_build_object(
    'success', true,
    'workout_id', v_workout_id,
    'workout_name', v_workout_name,
    'day', lower(day_name_param),
    'exercises', v_exercises
  );
end;
$$ language plpgsql security definer;

comment on function get_exercises_for_day_flat is 'Returns exercises for a specific day from workouts_flat table';

-- =====================================================
-- 3. START_SESSION
-- =====================================================
-- Create a new session for today or specified date
-- Optionally pre-populate with template exercises

create or replace function start_session(
  date_param date default current_date,
  workout_uuid uuid default null,
  session_notes_param text default null
)
returns json as $$
declare
  v_workout_id uuid;
  v_workout_name text;
  v_session_id uuid;
  v_existing_session_id uuid;
begin
  -- If no workout_id provided, use active workout
  if workout_uuid is null then
    select id into v_workout_id
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
    v_workout_id := workout_uuid;
  end if;

  -- Check if session already exists for this date
  select id into v_existing_session_id
  from sessions
  where workout_id = v_workout_id
    and date = date_param
  limit 1;

  if v_existing_session_id is not null then
    return json_build_object(
      'success', false,
      'message', 'Session already exists for this date',
      'session_id', v_existing_session_id,
      'date', date_param
    );
  end if;

  -- Get workout name
  select name into v_workout_name
  from workouts
  where id = v_workout_id;

  -- Create new session
  insert into sessions (workout_id, date, entries, notes)
  values (v_workout_id, date_param, '[]'::jsonb, session_notes_param)
  returning id into v_session_id;

  return json_build_object(
    'success', true,
    'message', 'Session started successfully',
    'session_id', v_session_id,
    'workout_id', v_workout_id,
    'workout_name', v_workout_name,
    'date', date_param
  );
end;
$$ language plpgsql security definer;

comment on function start_session is 'Creates a new workout session for a specific date';

-- =====================================================
-- 4. LOG_SET
-- =====================================================
-- Log a single set to an existing session
-- Uses flat table approach for easier data entry

create or replace function log_set(
  session_uuid uuid,
  exercise_name_param text,
  set_number_param int,
  reps_param int,
  weight_param numeric
)
returns json as $$
declare
  v_workout_id uuid;
  v_session_date date;
  v_session_notes text;
  v_new_entry jsonb;
  v_existing_entries jsonb;
  v_updated_entries jsonb;
begin
  -- Validate session exists
  select workout_id, date, notes into v_workout_id, v_session_date, v_session_notes
  from sessions
  where id = session_uuid;

  if v_workout_id is null then
    return json_build_object(
      'success', false,
      'message', 'Session not found',
      'session_id', session_uuid
    );
  end if;

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

  -- Create new entry
  v_new_entry := json_build_object(
    'exercise', exercise_name_param,
    'set', set_number_param,
    'reps', reps_param,
    'weight', weight_param
  )::jsonb;

  -- Get existing entries
  select entries into v_existing_entries from sessions where id = session_uuid;

  -- Remove any existing entry with same exercise and set number
  v_updated_entries := (
    select jsonb_agg(entry)
    from jsonb_array_elements(v_existing_entries) as entry
    where not (
      entry->>'exercise' = exercise_name_param
      and (entry->>'set')::int = set_number_param
    )
  );

  -- Handle case where all entries were removed
  if v_updated_entries is null then
    v_updated_entries := '[]'::jsonb;
  end if;

  -- Add new entry
  v_updated_entries := v_updated_entries || v_new_entry;

  -- Update session with new entries
  update sessions
  set entries = v_updated_entries
  where id = session_uuid;

  return json_build_object(
    'success', true,
    'message', 'Set logged successfully',
    'session_id', session_uuid,
    'exercise', exercise_name_param,
    'set', set_number_param,
    'reps', reps_param,
    'weight', weight_param
  );
end;
$$ language plpgsql security definer;

comment on function log_set is 'Logs a single set to a session. If a set with the same exercise and set number exists, it will be replaced.';

-- =====================================================
-- 5. LOG_MULTIPLE_SETS
-- =====================================================
-- Log multiple sets at once for efficiency

create or replace function log_multiple_sets(
  session_uuid uuid,
  sets_data jsonb
)
returns json as $$
declare
  v_workout_id uuid;
  v_count int := 0;
  v_set_entry jsonb;
  v_result json;
begin
  -- Validate session exists
  select workout_id into v_workout_id
  from sessions
  where id = session_uuid;

  if v_workout_id is null then
    return json_build_object(
      'success', false,
      'message', 'Session not found',
      'session_id', session_uuid
    );
  end if;

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
      session_uuid,
      v_set_entry->>'exercise',
      (v_set_entry->>'set')::int,
      (v_set_entry->>'reps')::int,
      (v_set_entry->>'weight')::numeric
    ) into v_result;

    if (v_result->>'success')::boolean then
      v_count := v_count + 1;
    end if;
  end loop;

  return json_build_object(
    'success', true,
    'message', format('Logged %s sets successfully', v_count),
    'session_id', session_uuid,
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
  session_uuid uuid
)
returns json as $$
declare
  v_session_info record;
  v_sets json;
begin
  -- Get session info
  select
    s.id,
    s.workout_id,
    w.name as workout_name,
    s.date,
    s.notes
  into v_session_info
  from sessions s
  join workouts w on w.id = s.workout_id
  where s.id = session_uuid;

  if v_session_info.id is null then
    return json_build_object(
      'success', false,
      'message', 'Session not found',
      'session_id', session_uuid
    );
  end if;

  -- Get sets from flat table
  select json_agg(
    json_build_object(
      'id', id,
      'exercise_name', exercise_name,
      'set_number', set_number,
      'reps', reps,
      'weight', weight
    ) order by exercise_name, set_number
  )
  into v_sets
  from sessions_flat
  where session_id = session_uuid;

  return json_build_object(
    'success', true,
    'session_id', v_session_info.id,
    'workout_id', v_session_info.workout_id,
    'workout_name', v_session_info.workout_name,
    'date', v_session_info.date,
    'notes', v_session_info.notes,
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
  v_session_id uuid;
  v_current_date date;
begin
  -- Get current date in Eastern Time
  v_current_date := (current_timestamp at time zone 'America/New_York')::date;

  -- Find today's session for active workout
  select s.id into v_session_id
  from sessions s
  join workouts w on w.id = s.workout_id
  where s.date = v_current_date
    and w.is_active = true
  limit 1;

  if v_session_id is null then
    return json_build_object(
      'success', false,
      'message', 'No session found for today',
      'date', v_current_date
    );
  end if;

  -- Return session details
  return get_session_sets_flat(v_session_id);
end;
$$ language plpgsql security definer;

comment on function get_todays_session is 'Returns today''s workout session with all sets from the active workout';

-- =====================================================
-- 8. UPDATE_SET
-- =====================================================
-- Update a specific set in a session

create or replace function update_set(
  session_uuid uuid,
  exercise_name_param text,
  set_number_param int,
  reps_param int default null,
  weight_param numeric default null
)
returns json as $$
declare
  v_workout_id uuid;
  v_existing_entries jsonb;
  v_updated_entries jsonb;
  v_found boolean := false;
begin
  -- Validate session exists
  select workout_id, entries into v_workout_id, v_existing_entries
  from sessions
  where id = session_uuid;

  if v_workout_id is null then
    return json_build_object(
      'success', false,
      'message', 'Session not found',
      'session_id', session_uuid
    );
  end if;

  -- Update the matching entry
  select jsonb_agg(
    case
      when entry->>'exercise' = exercise_name_param
        and (entry->>'set')::int = set_number_param
      then
        v_found := true,
        jsonb_build_object(
          'exercise', entry->>'exercise',
          'set', (entry->>'set')::int,
          'reps', coalesce(reps_param, (entry->>'reps')::int),
          'weight', coalesce(weight_param, (entry->>'weight')::numeric)
        )
      else entry
    end
  )
  into v_updated_entries
  from jsonb_array_elements(v_existing_entries) as entry;

  if not v_found then
    return json_build_object(
      'success', false,
      'message', 'Set not found',
      'exercise', exercise_name_param,
      'set', set_number_param
    );
  end if;

  -- Update session
  update sessions
  set entries = v_updated_entries
  where id = session_uuid;

  return json_build_object(
    'success', true,
    'message', 'Set updated successfully',
    'session_id', session_uuid,
    'exercise', exercise_name_param,
    'set', set_number_param
  );
end;
$$ language plpgsql security definer;

comment on function update_set is 'Updates a specific set in a session. Only provided parameters will be updated.';

-- =====================================================
-- 9. DELETE_SET
-- =====================================================
-- Delete a specific set from a session

create or replace function delete_set(
  session_uuid uuid,
  exercise_name_param text,
  set_number_param int
)
returns json as $$
declare
  v_workout_id uuid;
  v_existing_entries jsonb;
  v_updated_entries jsonb;
begin
  -- Validate session exists
  select workout_id, entries into v_workout_id, v_existing_entries
  from sessions
  where id = session_uuid;

  if v_workout_id is null then
    return json_build_object(
      'success', false,
      'message', 'Session not found',
      'session_id', session_uuid
    );
  end if;

  -- Remove the matching entry
  select jsonb_agg(entry)
  into v_updated_entries
  from jsonb_array_elements(v_existing_entries) as entry
  where not (
    entry->>'exercise' = exercise_name_param
    and (entry->>'set')::int = set_number_param
  );

  -- Handle case where all entries were removed
  if v_updated_entries is null then
    v_updated_entries := '[]'::jsonb;
  end if;

  -- Update session
  update sessions
  set entries = v_updated_entries
  where id = session_uuid;

  return json_build_object(
    'success', true,
    'message', 'Set deleted successfully',
    'session_id', session_uuid,
    'exercise', exercise_name_param,
    'set', set_number_param
  );
end;
$$ language plpgsql security definer;

comment on function delete_set is 'Deletes a specific set from a session';

-- =====================================================
-- 10. COMPLETE_SESSION
-- =====================================================
-- Mark session as complete and calculate history

create or replace function complete_session(
  session_uuid uuid,
  final_notes text default null
)
returns json as $$
declare
  v_session_date date;
  v_workout_id uuid;
  v_history_result json;
begin
  -- Validate session exists
  select date, workout_id into v_session_date, v_workout_id
  from sessions
  where id = session_uuid;

  if v_workout_id is null then
    return json_build_object(
      'success', false,
      'message', 'Session not found',
      'session_id', session_uuid
    );
  end if;

  -- Update notes if provided
  if final_notes is not null then
    update sessions
    set notes = final_notes
    where id = session_uuid;
  end if;

  -- Calculate history for this session date
  select calc_all_history(v_session_date) into v_history_result;

  return json_build_object(
    'success', true,
    'message', 'Session completed and history calculated',
    'session_id', session_uuid,
    'date', v_session_date,
    'history_result', v_history_result
  );
end;
$$ language plpgsql security definer;

comment on function complete_session is 'Marks a session as complete and calculates exercise/workout history';

-- =====================================================
-- 11. GET_EXERCISE_HISTORY_FLAT
-- =====================================================
-- Get history for a specific exercise from sessions_flat

create or replace function get_exercise_history_flat(
  exercise_name_param text,
  days_back int default 30,
  workout_uuid uuid default null
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
    and (workout_uuid is null or workout_id = workout_uuid);

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
      'date', session_date,
      'total_sets', count(*),
      'total_reps', sum(reps),
      'total_volume', sum(reps * weight),
      'max_weight', max(weight),
      'avg_weight', round(avg(weight)::numeric, 2)
    ) order by session_date desc
  )
  into v_summary
  from sessions_flat
  where exercise_name = exercise_name_param
    and session_date >= current_date - days_back
    and (workout_uuid is null or workout_id = workout_uuid)
  group by session_date;

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
-- 12. GET_WORKOUT_SUMMARY_FLAT
-- =====================================================
-- Get summary of a workout from sessions_flat

create or replace function get_workout_summary_flat(
  session_uuid uuid
)
returns json as $$
declare
  v_session_info record;
  v_summary json;
begin
  -- Get session info
  select
    s.id,
    s.workout_id,
    w.name as workout_name,
    s.date,
    s.notes
  into v_session_info
  from sessions s
  join workouts w on w.id = s.workout_id
  where s.id = session_uuid;

  if v_session_info.id is null then
    return json_build_object(
      'success', false,
      'message', 'Session not found',
      'session_id', session_uuid
    );
  end if;

  -- Get summary by exercise
  select json_agg(
    json_build_object(
      'exercise_name', exercise_name,
      'total_sets', count(*),
      'total_reps', sum(reps),
      'total_volume', sum(reps * weight),
      'max_weight', max(weight),
      'avg_weight', round(avg(weight)::numeric, 2)
    ) order by min(created_at)
  )
  into v_summary
  from sessions_flat
  where session_id = session_uuid
  group by exercise_name;

  return json_build_object(
    'success', true,
    'session_id', v_session_info.id,
    'workout_id', v_session_info.workout_id,
    'workout_name', v_session_info.workout_name,
    'date', v_session_info.date,
    'notes', v_session_info.notes,
    'summary', coalesce(v_summary, '[]'::json)
  );
end;
$$ language plpgsql security definer;

comment on function get_workout_summary_flat is 'Returns summary statistics for a workout session grouped by exercise';
