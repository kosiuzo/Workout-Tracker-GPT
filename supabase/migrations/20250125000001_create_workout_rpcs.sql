-- =====================================================
-- RPC Functions for Workout Management
-- =====================================================
-- 1. create_workout - Create new workout with name and description
-- 2. add_workout_day - Append exercises for a day to existing workout
-- 3. set_active_workout - Set a workout as active and deactivate others
-- 4. get_active_workout - Get active workout grouped by day as JSON
-- 5. log_current_workout - Log active workout for a day to sessions table
-- =====================================================

-- =====================================================
-- 1. CREATE_WORKOUT
-- =====================================================
-- Creates a new workout with name and description
-- Fails if workout_name already exists
-- Sets workout_is_active to false by default

create or replace function create_workout(
  p_workout_name text,
  p_workout_description text
)
returns jsonb as $$
declare
  v_exists boolean;
begin
  -- Check if workout already exists
  select exists(
    select 1 from workouts where workout_name = p_workout_name
  ) into v_exists;

  if v_exists then
    raise exception 'Workout "%" already exists', p_workout_name;
  end if;

  -- Create a placeholder row to establish the workout
  -- This ensures the workout exists for subsequent add_workout_day calls
  insert into workouts (
    workout_name,
    workout_description,
    workout_is_active,
    day_name,
    exercise_order,
    exercise_name,
    sets,
    reps,
    weight
  ) values (
    p_workout_name,
    p_workout_description,
    false,
    'placeholder',
    0,
    'placeholder',
    0,
    0,
    0
  );

  -- Return success response
  return jsonb_build_object(
    'success', true,
    'message', 'Workout created successfully',
    'workout_name', p_workout_name,
    'workout_description', p_workout_description
  );
end;
$$ language plpgsql;

-- =====================================================
-- 2. ADD_WORKOUT_DAY
-- =====================================================
-- Appends exercises for a day to an existing workout
-- Input: p_exercises is JSON array of exercise objects
-- [{exercise_name, sets, reps, weight, exercise_order, superset_group, exercise_notes}, ...]

create or replace function add_workout_day(
  p_workout_name text,
  p_day_name text,
  p_exercises jsonb
)
returns jsonb as $$
declare
  v_exercise jsonb;
  v_exercise_count int := 0;
  v_added_count int := 0;
  v_exists boolean;
  v_workout_description text;
  v_is_active boolean;
begin
  -- Check if workout exists
  select exists(
    select 1 from workouts where workout_name = p_workout_name
  ) into v_exists;

  if not v_exists then
    raise exception 'Workout "%" does not exist', p_workout_name;
  end if;

  -- Get workout description and active status for new rows (from any row)
  select workout_description, workout_is_active into v_workout_description, v_is_active
  from workouts
  where workout_name = p_workout_name
  limit 1;

  -- Insert each exercise from the JSON array
  for v_exercise in select jsonb_array_elements(p_exercises)
  loop
    insert into workouts (
      workout_name,
      workout_description,
      workout_is_active,
      day_name,
      exercise_order,
      exercise_name,
      sets,
      reps,
      weight,
      superset_group,
      exercise_notes
    ) values (
      p_workout_name,
      v_workout_description,
      v_is_active,
      p_day_name,
      (v_exercise->>'exercise_order')::float,
      v_exercise->>'exercise_name',
      (v_exercise->>'sets')::int,
      (v_exercise->>'reps')::int,
      (v_exercise->>'weight')::int,
      v_exercise->>'superset_group',
      v_exercise->>'exercise_notes'
    );

    v_added_count := v_added_count + 1;
  end loop;

  return jsonb_build_object(
    'success', true,
    'message', 'Exercises added successfully',
    'workout_name', p_workout_name,
    'day_name', p_day_name,
    'exercises_added', v_added_count
  );
end;
$$ language plpgsql;

-- =====================================================
-- 3. SET_ACTIVE_WORKOUT
-- =====================================================
-- Sets the specified workout as active and deactivates all others

create or replace function set_active_workout(
  p_workout_name text
)
returns jsonb as $$
declare
  v_exists boolean;
begin
  -- Check if workout exists
  select exists(
    select 1 from workouts where workout_name = p_workout_name
  ) into v_exists;

  if not v_exists then
    raise exception 'Workout "%" does not exist', p_workout_name;
  end if;

  -- Deactivate all workouts
  update workouts set workout_is_active = false;

  -- Activate the specified workout
  update workouts set workout_is_active = true where workout_name = p_workout_name;

  return jsonb_build_object(
    'success', true,
    'message', 'Workout activated successfully',
    'workout_name', p_workout_name,
    'is_active', true
  );
end;
$$ language plpgsql;

-- =====================================================
-- 4. GET_ACTIVE_WORKOUT
-- =====================================================
-- Returns active workout grouped by day as JSON
-- Format: {workout_name, workout_description, days: {day_name: [{exercises}]}}

create or replace function get_active_workout()
returns jsonb as $$
declare
  v_workout_name text;
  v_workout_description text;
  v_result jsonb;
begin
  -- Get active workout name and description
  select workout_name, workout_description
  into v_workout_name, v_workout_description
  from workouts
  where workout_is_active = true
  limit 1;

  if v_workout_name is null then
    raise exception 'No active workout found';
  end if;

  -- Build JSON grouped by day (exclude placeholder rows)
  select jsonb_build_object(
    'workout_name', v_workout_name,
    'workout_description', v_workout_description,
    'days', jsonb_object_agg(
      w1.day_name,
      (
        select jsonb_agg(
          jsonb_build_object(
            'exercise_name', exercise_name,
            'sets', sets,
            'reps', reps,
            'weight', weight,
            'exercise_order', exercise_order,
            'superset_group', superset_group,
            'exercise_notes', exercise_notes
          )
          order by exercise_order
        )
        from workouts w2
        where w2.workout_name = v_workout_name
          and w2.day_name = w1.day_name
          and w2.exercise_name != 'placeholder'
      )
    )
  )
  into v_result
  from (
    select distinct day_name
    from workouts
    where workout_name = v_workout_name
      and exercise_name != 'placeholder'
    order by day_name
  ) as w1;

  return v_result;
end;
$$ language plpgsql;

-- =====================================================
-- 5. LOG_CURRENT_WORKOUT
-- =====================================================
-- Logs active workout for a day to sessions table
-- If p_day_name is NULL, uses current day of week
-- Copies sets, reps, weight from workout template

create or replace function log_current_workout(
  p_day_name text default null,
  p_session_date date default current_date
)
returns jsonb as $$
declare
  v_workout_name text;
  v_day_name text;
  v_exercise_count int := 0;
  v_exercise record;
begin
  -- Get active workout
  select workout_name into v_workout_name
  from workouts
  where workout_is_active = true
  limit 1;

  if v_workout_name is null then
    raise exception 'No active workout found';
  end if;

  -- Determine which day to log
  if p_day_name is null then
    v_day_name := lower(to_char(p_session_date, 'Day'));
    v_day_name := trim(v_day_name);  -- Remove trailing spaces from to_char
  else
    v_day_name := p_day_name;
  end if;

  -- Insert exercises for the day into sessions (exclude placeholders)
  insert into sessions (
    workout_name,
    session_date,
    exercise_name,
    sets,
    reps,
    weight
  )
  select
    workout_name,
    p_session_date,
    exercise_name,
    sets,
    reps,
    weight
  from workouts
  where workout_name = v_workout_name
    and day_name = v_day_name
    and exercise_name != 'placeholder';

  get diagnostics v_exercise_count = row_count;

  if v_exercise_count = 0 then
    raise exception 'No exercises found for % on day "%"', v_workout_name, v_day_name;
  end if;

  return jsonb_build_object(
    'success', true,
    'message', 'Workout logged successfully',
    'workout_name', v_workout_name,
    'session_date', p_session_date,
    'day_name', v_day_name,
    'exercises_logged', v_exercise_count
  );
end;
$$ language plpgsql;

-- =====================================================
-- GRANT PERMISSIONS
-- =====================================================
-- Allow anonymous users to call these functions

grant execute on function create_workout(text, text) to anon;
grant execute on function add_workout_day(text, text, jsonb) to anon;
grant execute on function set_active_workout(text) to anon;
grant execute on function get_active_workout() to anon;
grant execute on function log_current_workout(text, date) to anon;
