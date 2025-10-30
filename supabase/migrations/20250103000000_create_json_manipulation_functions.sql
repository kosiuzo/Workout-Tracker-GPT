-- =====================================================
-- Workout Tracker GPT v1.0 - JSON Manipulation Functions
-- =====================================================
-- Surgical editing functions for JSONB fields
-- Enables precise updates without replacing entire objects
-- =====================================================

-- =====================================================
-- 1. UPDATE_WORKOUT_DAY_WEIGHT
-- =====================================================
-- Updates a specific exercise's weight in the workout template
-- Targets: workouts.days JSONB

create or replace function update_workout_day_weight(
  workout_uuid uuid,
  day_name text,
  exercise_name text,
  new_weight int
)
returns json as $$
declare
  v_updated_day jsonb;
  v_workout_name text;
  v_old_weight int;
  v_found boolean := false;
begin
  -- Normalize day name to lowercase
  day_name := lower(day_name);

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

  -- Build updated day array with modified exercise
  select jsonb_agg(
    case
      when (exercise->>'exercise' = exercise_name) then
        jsonb_set(exercise, '{weight}', to_jsonb(new_weight::int))
      else
        exercise
    end
  )
  into v_updated_day
  from jsonb_array_elements(
    (select days->day_name from workouts where id = workout_uuid)
  ) as exercise;

  -- Check if the day exists
  if v_updated_day is null then
    return json_build_object(
      'success', false,
      'error', format('Day "%s" not found in workout', day_name),
      'workout_id', workout_uuid,
      'workout_name', v_workout_name
    );
  end if;

  -- Get old weight for response
  select (exercise->>'weight')::int
  into v_old_weight
  from jsonb_array_elements(
    (select days->day_name from workouts where id = workout_uuid)
  ) as exercise
  where exercise->>'exercise' = exercise_name
  limit 1;

  if v_old_weight is not null then
    v_found := true;
  end if;

  -- Update the workout with modified day
  update workouts
  set days = jsonb_set(days, array[day_name]::text[], v_updated_day)
  where id = workout_uuid;

  if not v_found then
    return json_build_object(
      'success', false,
      'error', format('Exercise "%s" not found on %s', exercise_name, day_name),
      'workout_id', workout_uuid,
      'workout_name', v_workout_name
    );
  end if;

  return json_build_object(
    'success', true,
    'workout_id', workout_uuid,
    'workout_name', v_workout_name,
    'day', day_name,
    'exercise', exercise_name,
    'old_weight', v_old_weight,
    'new_weight', new_weight,
    'message', format('Updated %s weight from %s to %s lbs', exercise_name, v_old_weight, new_weight)
  );
end;
$$ language plpgsql security definer;

comment on function update_workout_day_weight is 'Updates a specific exercise weight in a workout day template. Returns old and new values.';

-- =====================================================
-- 2. UPDATE_ENTRY_WEIGHT
-- =====================================================
-- Updates a specific set's weight in a session
-- Targets: sessions.entries JSONB

create or replace function update_entry_weight(
  session_uuid uuid,
  exercise_name text,
  set_number int,
  new_weight int
)
returns json as $$
declare
  v_updated_entries jsonb;
  v_session_date date;
  v_old_weight int;
  v_found boolean := false;
begin
  -- Check if session exists
  select date into v_session_date
  from sessions
  where id = session_uuid;

  if v_session_date is null then
    return json_build_object(
      'success', false,
      'error', 'Session not found',
      'session_id', session_uuid
    );
  end if;

  -- Get old weight for response
  select (entry->>'weight')::int
  into v_old_weight
  from jsonb_array_elements(
    (select entries from sessions where id = session_uuid)
  ) as entry
  where entry->>'exercise' = exercise_name
    and (entry->>'set')::int = set_number
  limit 1;

  if v_old_weight is not null then
    v_found := true;
  end if;

  -- Build updated entries array with modified weight
  select jsonb_agg(
    case
      when (entry->>'exercise' = exercise_name and (entry->>'set')::int = set_number) then
        jsonb_set(entry, '{weight}', to_jsonb(new_weight::int))
      else
        entry
    end
  )
  into v_updated_entries
  from jsonb_array_elements(
    (select entries from sessions where id = session_uuid)
  ) as entry;

  -- Update the session with modified entries
  update sessions
  set entries = v_updated_entries
  where id = session_uuid;

  if not v_found then
    return json_build_object(
      'success', false,
      'error', format('Set %s of %s not found in session', set_number, exercise_name),
      'session_id', session_uuid,
      'session_date', v_session_date
    );
  end if;

  return json_build_object(
    'success', true,
    'session_id', session_uuid,
    'session_date', v_session_date,
    'exercise', exercise_name,
    'set_number', set_number,
    'old_weight', v_old_weight,
    'new_weight', new_weight,
    'message', format('Updated %s set %s weight from %s to %s lbs', exercise_name, set_number, v_old_weight, new_weight)
  );
end;
$$ language plpgsql security definer;

comment on function update_entry_weight is 'Updates a specific set weight in a session entry. Returns old and new values.';

-- =====================================================
-- 3. UPDATE_ENTRY_REPS
-- =====================================================
-- Updates a specific set's reps in a session
-- Targets: sessions.entries JSONB

create or replace function update_entry_reps(
  session_uuid uuid,
  exercise_name text,
  set_number int,
  new_reps int
)
returns json as $$
declare
  v_updated_entries jsonb;
  v_session_date date;
  v_old_reps int;
  v_found boolean := false;
begin
  -- Check if session exists
  select date into v_session_date
  from sessions
  where id = session_uuid;

  if v_session_date is null then
    return json_build_object(
      'success', false,
      'error', 'Session not found',
      'session_id', session_uuid
    );
  end if;

  -- Get old reps for response
  select (entry->>'reps')::int
  into v_old_reps
  from jsonb_array_elements(
    (select entries from sessions where id = session_uuid)
  ) as entry
  where entry->>'exercise' = exercise_name
    and (entry->>'set')::int = set_number
  limit 1;

  if v_old_reps is not null then
    v_found := true;
  end if;

  -- Build updated entries array with modified reps
  select jsonb_agg(
    case
      when (entry->>'exercise' = exercise_name and (entry->>'set')::int = set_number) then
        jsonb_set(entry, '{reps}', to_jsonb(new_reps::int))
      else
        entry
    end
  )
  into v_updated_entries
  from jsonb_array_elements(
    (select entries from sessions where id = session_uuid)
  ) as entry;

  -- Update the session with modified entries
  update sessions
  set entries = v_updated_entries
  where id = session_uuid;

  if not v_found then
    return json_build_object(
      'success', false,
      'error', format('Set %s of %s not found in session', set_number, exercise_name),
      'session_id', session_uuid,
      'session_date', v_session_date
    );
  end if;

  return json_build_object(
    'success', true,
    'session_id', session_uuid,
    'session_date', v_session_date,
    'exercise', exercise_name,
    'set_number', set_number,
    'old_reps', v_old_reps,
    'new_reps', new_reps,
    'message', format('Updated %s set %s reps from %s to %s', exercise_name, set_number, v_old_reps, new_reps)
  );
end;
$$ language plpgsql security definer;

comment on function update_entry_reps is 'Updates a specific set reps in a session entry. Returns old and new values.';

-- =====================================================
-- 4. ADD_EXERCISE_TO_DAY
-- =====================================================
-- Adds a new exercise to a workout day
-- Creates the day if it doesn't exist

create or replace function add_exercise_to_day(
  workout_uuid uuid,
  day_name text,
  exercise_name text,
  sets int,
  reps int,
  weight int,
  superset_group text default null,
  notes text default null
)
returns json as $$
declare
  v_workout_name text;
  v_current_day jsonb;
  v_new_exercise jsonb;
  v_updated_day jsonb;
begin
  -- Normalize day name
  day_name := lower(day_name);

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

  -- Build new exercise object
  v_new_exercise := jsonb_build_object(
    'exercise', exercise_name,
    'sets', sets,
    'reps', reps,
    'weight', weight
  );

  if superset_group is not null then
    v_new_exercise := v_new_exercise || jsonb_build_object('superset_group', superset_group);
  end if;

  if notes is not null then
    v_new_exercise := v_new_exercise || jsonb_build_object('notes', notes);
  end if;

  -- Get current day exercises (or empty array if day doesn't exist)
  select coalesce(days->day_name, '[]'::jsonb)
  into v_current_day
  from workouts
  where id = workout_uuid;

  -- Append new exercise to day
  v_updated_day := v_current_day || v_new_exercise;

  -- Update workout with new day
  update workouts
  set days = jsonb_set(
    coalesce(days, '{}'::jsonb),
    array[day_name]::text[],
    v_updated_day
  )
  where id = workout_uuid;

  return json_build_object(
    'success', true,
    'workout_id', workout_uuid,
    'workout_name', v_workout_name,
    'day', day_name,
    'exercise', exercise_name,
    'message', format('Added %s to %s', exercise_name, day_name)
  );
end;
$$ language plpgsql security definer;

comment on function add_exercise_to_day is 'Adds a new exercise to a workout day. Creates the day if it does not exist.';

-- =====================================================
-- 5. REMOVE_EXERCISE_FROM_DAY
-- =====================================================
-- Removes an exercise from a workout day

create or replace function remove_exercise_from_day(
  workout_uuid uuid,
  day_name text,
  exercise_name text
)
returns json as $$
declare
  v_workout_name text;
  v_current_day jsonb;
  v_updated_day jsonb;
  v_found boolean := false;
begin
  -- Normalize day name
  day_name := lower(day_name);

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

  -- Get current day exercises
  select days->day_name
  into v_current_day
  from workouts
  where id = workout_uuid;

  if v_current_day is null then
    return json_build_object(
      'success', false,
      'error', format('Day "%s" not found in workout', day_name),
      'workout_id', workout_uuid,
      'workout_name', v_workout_name
    );
  end if;

  -- Build updated day without the specified exercise
  select jsonb_agg(exercise)
  into v_updated_day
  from jsonb_array_elements(v_current_day) as exercise
  where exercise->>'exercise' <> exercise_name;

  -- Check if exercise was found
  if jsonb_array_length(v_updated_day) < jsonb_array_length(v_current_day) then
    v_found := true;
  end if;

  if not v_found then
    return json_build_object(
      'success', false,
      'error', format('Exercise "%s" not found on %s', exercise_name, day_name),
      'workout_id', workout_uuid,
      'workout_name', v_workout_name
    );
  end if;

  -- Update workout with modified day
  update workouts
  set days = jsonb_set(days, array[day_name]::text[], coalesce(v_updated_day, '[]'::jsonb))
  where id = workout_uuid;

  return json_build_object(
    'success', true,
    'workout_id', workout_uuid,
    'workout_name', v_workout_name,
    'day', day_name,
    'exercise', exercise_name,
    'message', format('Removed %s from %s', exercise_name, day_name)
  );
end;
$$ language plpgsql security definer;

comment on function remove_exercise_from_day is 'Removes an exercise from a workout day.';
