-- =====================================================
-- Update RPC Functions for Renamed Tables
-- =====================================================
-- Updates all RPC functions to use the new table names:
-- - workouts_flat → workouts
-- - sessions_flat → sessions
-- =====================================================

-- =====================================================
-- 1. UPDATE GET_TODAYS_EXERCISES_FLAT
-- =====================================================

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
  from workouts
  where workout_is_active = true
  limit 1;

  if v_workout_name is null then
    return json_build_object(
      'success', false,
      'message', 'No active workout found',
      'current_day', v_current_day
    );
  end if;

  -- Get exercises for today from new workouts table
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
  from workouts
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

-- =====================================================
-- 2. UPDATE GET_EXERCISES_FOR_DAY_FLAT
-- =====================================================

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
    from workouts
    where workout_is_active = true
    limit 1;
  else
    select workout_name into v_workout_name
    from workouts
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
  from workouts
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

-- =====================================================
-- 3. UPDATE LOG_SET
-- =====================================================

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

  -- Insert or replace set in sessions table
  insert into sessions (workout_name, session_date, exercise_name, set_number, reps, weight, session_notes)
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

-- =====================================================
-- 4. UPDATE LOG_MULTIPLE_SETS
-- =====================================================
-- No changes needed - it calls log_set which is updated

-- =====================================================
-- 5. UPDATE GET_SESSION_SETS_FLAT
-- =====================================================

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
  from sessions
  where workout_name = workout_name_param
    and session_date = session_date_param
  limit 1;

  if v_session_notes is null and not exists(
    select 1 from sessions
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

  -- Get sets from new sessions table
  select json_agg(
    json_build_object(
      'exercise_name', exercise_name,
      'set_number', set_number,
      'reps', reps,
      'weight', weight
    ) order by exercise_name, set_number
  )
  into v_sets
  from sessions
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

-- =====================================================
-- 6. UPDATE GET_TODAYS_SESSION
-- =====================================================

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
  from workouts
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

-- =====================================================
-- 7. UPDATE UPDATE_SET
-- =====================================================

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
  from sessions
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
  update sessions
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

-- =====================================================
-- 8. UPDATE DELETE_SET
-- =====================================================

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
  delete from sessions
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

-- =====================================================
-- 9. UPDATE UPDATE_SESSION_NOTES
-- =====================================================

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
  update sessions
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

-- =====================================================
-- 10. UPDATE GET_EXERCISE_HISTORY_FLAT
-- =====================================================

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
  -- Get detailed history from new sessions table
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
  from sessions
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
    from sessions
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

-- =====================================================
-- 11. UPDATE GET_WORKOUT_SUMMARY_FLAT
-- =====================================================

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
  from sessions
  where workout_name = workout_name_param
    and session_date = session_date_param
  limit 1;

  if v_session_notes is null and not exists(
    select 1 from sessions
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
    from sessions
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

-- =====================================================
-- 12. UPDATE SET_ACTIVE_WORKOUT
-- =====================================================

create or replace function set_active_workout(workout_name_param text)
returns json as $$
declare
  v_result json;
begin
  -- Check if workout exists
  if not exists (select 1 from workouts where workout_name = workout_name_param) then
    return json_build_object(
      'success', false,
      'error', 'Workout not found',
      'workout_name', workout_name_param
    );
  end if;

  -- Deactivate all workouts
  update workouts set workout_is_active = false where workout_is_active = true;

  -- Activate the target workout
  update workouts set workout_is_active = true where workout_name = workout_name_param;

  return json_build_object(
    'success', true,
    'message', 'Workout activated successfully',
    'workout_name', workout_name_param
  );
end;
$$ language plpgsql security definer;

-- =====================================================
-- 13. UPDATE CREATE_WORKOUT_FROM_JSON
-- =====================================================

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
  v_exercise_order float;
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
  if exists (select 1 from workouts where workout_name = v_workout_name) then
    return json_build_object(
      'success', false,
      'error', 'Workout already exists',
      'workout_name', v_workout_name
    );
  end if;

  -- If marking as active, first deactivate any existing active workouts
  if v_is_active then
    update workouts set workout_is_active = false where workout_is_active = true;
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
        insert into workouts (
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
        v_exercise_order := v_exercise_order + 1.0;
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
