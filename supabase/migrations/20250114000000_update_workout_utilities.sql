-- =====================================================
-- Update Workout Utility Functions
-- =====================================================
-- 1. Update set_active_workout to use workout_name instead of UUID
-- 2. Create create_workout_from_json to accept JSON and populate flat tables
-- =====================================================

-- =====================================================
-- 1. UPDATE SET_ACTIVE_WORKOUT
-- =====================================================
-- Changed from UUID to workout_name (text)

drop function if exists set_active_workout(uuid) cascade;

create or replace function set_active_workout(workout_name_param text)
returns json as $$
declare
  v_result json;
begin
  -- Check if workout exists
  if not exists (select 1 from workouts_flat where workout_name = workout_name_param) then
    return json_build_object(
      'success', false,
      'error', 'Workout not found',
      'workout_name', workout_name_param
    );
  end if;

  -- Deactivate all workouts
  update workouts_flat set workout_is_active = false where workout_is_active = true;

  -- Activate the target workout
  update workouts_flat set workout_is_active = true where workout_name = workout_name_param;

  return json_build_object(
    'success', true,
    'message', 'Workout activated successfully',
    'workout_name', workout_name_param
  );
end;
$$ language plpgsql security definer;

comment on function set_active_workout is 'Activates a workout by name and deactivates all others. Now uses workout_name (text) instead of UUID.';

-- =====================================================
-- 2. CREATE_WORKOUT_FROM_JSON
-- =====================================================
-- Creates a complete workout from JSON structure
-- Accepts JSON with workout metadata and array of days with exercises
-- Automatically populates workouts_flat and inserts into workouts table

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
  v_workout_id uuid;
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
  if exists (select 1 from workouts_flat where workout_name = v_workout_name) then
    return json_build_object(
      'success', false,
      'error', 'Workout already exists',
      'workout_name', v_workout_name
    );
  end if;

  -- Insert into workouts table if not exists
  -- If marking as active, first deactivate any existing active workouts
  if v_is_active then
    update workouts set is_active = false where is_active = true;
  end if;

  if not exists (select 1 from workouts where name = v_workout_name) then
    insert into workouts (name, description, days, is_active)
    values (v_workout_name, v_workout_description, '{}'::jsonb, v_is_active)
    returning id into v_workout_id;
  else
    select id into v_workout_id from workouts where name = v_workout_name;
    -- Update is_active if needed
    if v_is_active then
      update workouts set is_active = true where name = v_workout_name;
    end if;
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

comment on function create_workout_from_json is 'Creates a complete workout from JSON structure. Accepts JSON with workout_name, workout_description, is_active, and days array with exercises. Automatically populates workouts_flat table.';

-- =====================================================
-- EXAMPLE JSON STRUCTURE
-- =====================================================
-- {
--   "workout_name": "Push/Pull/Legs v1",
--   "workout_description": "Classic PPL split...",
--   "is_active": true,
--   "days": [
--     {
--       "day_name": "monday",
--       "day_notes": "Push day - focus on form",
--       "exercises": [
--         {
--           "exercise_name": "Bench Press",
--           "sets": 4,
--           "reps": 8,
--           "weight": 185,
--           "superset_group": null,
--           "exercise_notes": "Barbell, touch chest each rep"
--         },
--         {
--           "exercise_name": "Incline Dumbbell Press",
--           "sets": 3,
--           "reps": 10,
--           "weight": 60,
--           "superset_group": null,
--           "exercise_notes": "45-degree angle"
--         }
--       ]
--     },
--     {
--       "day_name": "tuesday",
--       "day_notes": "Pull day",
--       "exercises": [...]
--     }
--   ]
-- }
