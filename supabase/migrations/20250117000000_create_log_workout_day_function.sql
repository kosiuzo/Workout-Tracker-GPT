-- =====================================================
-- Log Workout Day Function
-- =====================================================
-- Logs all sets for a workout day in a single call
-- Defaults to active workout and current day
-- =====================================================

-- =====================================================
-- CREATE LOG_WORKOUT_DAY FUNCTION
-- =====================================================
-- Accepts performance data and logs to sessions_flat
-- Automatically determines workout and day if not specified

create or replace function log_workout_day(
  sets_data jsonb,
  day_name_param text default null,
  workout_name_param text default null,
  session_date_param date default current_date,
  session_notes_param text default null
)
returns json as $$
declare
  v_workout_name text;
  v_day_name text;
  v_set_obj jsonb;
  v_exercise_name text;
  v_set_number int;
  v_reps int;
  v_weight numeric;
  v_rows_inserted int := 0;
  v_rows_updated int := 0;
  v_is_insert boolean;
begin
  -- Validate sets_data
  if sets_data is null or jsonb_typeof(sets_data) != 'array' then
    return json_build_object(
      'success', false,
      'error', 'sets_data must be a JSON array'
    );
  end if;

  -- Determine workout_name (use provided or get active workout)
  if workout_name_param is not null and trim(workout_name_param) != '' then
    v_workout_name := workout_name_param;

    -- Verify workout exists
    if not exists (select 1 from workouts_flat where workout_name = v_workout_name) then
      return json_build_object(
        'success', false,
        'error', 'Workout not found',
        'workout_name', v_workout_name
      );
    end if;
  else
    -- Get active workout name
    select distinct workout_name into v_workout_name
    from workouts_flat
    where workout_is_active = true
    limit 1;

    if v_workout_name is null then
      return json_build_object(
        'success', false,
        'error', 'No active workout found. Please specify workout_name or set an active workout.'
      );
    end if;
  end if;

  -- Determine day_name (use provided or get current day of week)
  if day_name_param is not null and trim(day_name_param) != '' then
    v_day_name := lower(trim(day_name_param));
  else
    -- Get current day of week (monday, tuesday, etc.)
    v_day_name := lower(to_char(session_date_param, 'Day'));
    v_day_name := trim(v_day_name);
  end if;

  -- Verify the day exists in the workout plan
  if not exists (
    select 1 from workouts_flat
    where workout_name = v_workout_name
    and day_name = v_day_name
  ) then
    return json_build_object(
      'success', false,
      'error', format('Day "%s" not found in workout "%s"', v_day_name, v_workout_name),
      'workout_name', v_workout_name,
      'day_name', v_day_name
    );
  end if;

  -- Process each set in the sets_data array
  for v_set_obj in select jsonb_array_elements(sets_data)
  loop
    -- Extract set data
    v_exercise_name := trim(v_set_obj->>'exercise_name');
    v_set_number := (v_set_obj->>'set_number')::int;
    v_reps := (v_set_obj->>'reps')::int;
    v_weight := (v_set_obj->>'weight')::numeric;

    -- Validate required fields
    if v_exercise_name is null or v_exercise_name = '' then
      continue; -- Skip invalid entries
    end if;

    if v_set_number is null or v_reps is null or v_weight is null then
      continue; -- Skip incomplete entries
    end if;

    -- Insert or update the set in sessions_flat
    insert into sessions_flat (
      workout_name,
      session_date,
      session_notes,
      exercise_name,
      set_number,
      reps,
      weight
    )
    values (
      v_workout_name,
      session_date_param,
      session_notes_param,
      v_exercise_name,
      v_set_number,
      v_reps,
      v_weight
    )
    on conflict (workout_name, session_date, exercise_name, set_number)
    do update set
      reps = excluded.reps,
      weight = excluded.weight,
      session_notes = coalesce(excluded.session_notes, sessions_flat.session_notes),
      updated_at = now()
    returning (xmax = 0) into v_is_insert;

    if v_is_insert then
      v_rows_inserted := v_rows_inserted + 1;
    else
      v_rows_updated := v_rows_updated + 1;
    end if;
  end loop;

  -- Return success with details
  return json_build_object(
    'success', true,
    'workout_name', v_workout_name,
    'day_name', v_day_name,
    'session_date', session_date_param,
    'rows_inserted', v_rows_inserted,
    'rows_updated', v_rows_updated,
    'total_sets', v_rows_inserted + v_rows_updated,
    'message', format('Logged %s sets for %s on %s (%s)',
      v_rows_inserted + v_rows_updated,
      v_workout_name,
      session_date_param,
      v_day_name
    )
  );
exception
  when others then
    return json_build_object(
      'success', false,
      'error', 'Failed to log workout day',
      'details', SQLERRM
    );
end;
$$ language plpgsql security definer;

comment on function log_workout_day is 'Logs all sets for a workout day in a single call. Defaults to active workout and current day of week. Accepts JSON array of sets with exercise_name, set_number, reps, and weight. Automatically inserts or updates existing sets.';

-- =====================================================
-- EXAMPLE USAGE
-- =====================================================

-- Example 1: Log today's workout (uses active workout and current day)
-- SELECT log_workout_day('[
--   {"exercise_name": "Bench Press", "set_number": 1, "reps": 10, "weight": 185},
--   {"exercise_name": "Bench Press", "set_number": 2, "reps": 9, "weight": 185},
--   {"exercise_name": "Bench Press", "set_number": 3, "reps": 8, "weight": 185},
--   {"exercise_name": "Incline Press", "set_number": 1, "reps": 12, "weight": 135},
--   {"exercise_name": "Incline Press", "set_number": 2, "reps": 11, "weight": 135}
-- ]'::jsonb);

-- Example 2: Log specific day and workout
-- SELECT log_workout_day(
--   '[
--     {"exercise_name": "Deadlift", "set_number": 1, "reps": 5, "weight": 315},
--     {"exercise_name": "Deadlift", "set_number": 2, "reps": 5, "weight": 315}
--   ]'::jsonb,
--   'friday',           -- day_name
--   'PPL v1',          -- workout_name
--   '2025-01-17',      -- session_date
--   'Felt strong today' -- session_notes
-- );

-- Example 3: Log with session notes (uses active workout and current day)
-- SELECT log_workout_day(
--   '[...]'::jsonb,
--   null,              -- day_name (defaults to current day)
--   null,              -- workout_name (defaults to active)
--   current_date,      -- session_date (today)
--   'Great pump!'      -- session_notes
-- );
