-- =====================================================
-- Allow Duplicate Workout Names
-- =====================================================
-- Removes the workout name uniqueness check from create_workout_from_json
-- Uniqueness is enforced by the composite primary key (workout_name, day_name, exercise_order)
-- This allows users to create multiple workouts with the same name
-- =====================================================

-- =====================================================
-- UPDATE CREATE_WORKOUT_FROM_JSON FUNCTION
-- =====================================================
-- Remove the duplicate workout name check to allow same workout names
-- Table's composite key ensures actual data integrity

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

  -- REMOVED: Duplicate workout name check
  -- The composite primary key (workout_name, day_name, exercise_order) provides actual uniqueness
  -- This allows users to break large workouts into multiple inserts with the same name

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

comment on function create_workout_from_json is 'Creates a complete workout from JSON structure. Accepts JSON with workout_name, workout_description, is_active, and days array with exercises. Allows duplicate workout names - uniqueness is enforced by the composite primary key (workout_name, day_name, exercise_order).';
