-- =====================================================
-- Workout Tracker GPT - Update Create Workout RPC
-- =====================================================
-- Migration to make workout_days required and add strict validation
-- =====================================================

-- =====================================================
-- DROP EXISTING FUNCTION
-- =====================================================
drop function if exists create_workout(text, text, jsonb, boolean);

-- =====================================================
-- CREATE UPDATED CREATE_WORKOUT FUNCTION
-- =====================================================
-- Creates a new workout plan with validation and optional activation
-- Requires workout_days to be provided and non-empty
-- Ensures data integrity and consistent response format

create or replace function create_workout(
  workout_name text,
  workout_days jsonb,
  workout_description text default null,
  make_active boolean default false
)
returns json as $$
declare
  v_workout_id uuid;
  v_result json;
begin
  -- Validate workout name
  if workout_name is null or trim(workout_name) = '' then
    return json_build_object(
      'success', false,
      'error', 'Workout name is required'
    );
  end if;

  -- Validate workout_days is provided and not null
  if workout_days is null then
    return json_build_object(
      'success', false,
      'error', 'Workout days are required'
    );
  end if;

  -- Validate days structure (ensure it's a valid JSON object)
  if jsonb_typeof(workout_days) != 'object' then
    return json_build_object(
      'success', false,
      'error', 'Workout days must be a valid JSON object'
    );
  end if;

  -- Validate that workout_days is not empty (has at least one key)
  if (select count(*) from jsonb_object_keys(workout_days)) = 0 then
    return json_build_object(
      'success', false,
      'error', 'Workout days cannot be empty. At least one day with exercises is required.'
    );
  end if;

  -- Check for duplicate name
  if exists(select 1 from workouts where name = workout_name) then
    return json_build_object(
      'success', false,
      'error', 'A workout with this name already exists',
      'duplicate_name', workout_name
    );
  end if;

  -- If making active, deactivate others first
  if make_active then
    update workouts set is_active = false where is_active = true;
  end if;

  -- Create the workout
  insert into workouts (name, description, days, is_active)
  values (workout_name, workout_description, workout_days, make_active)
  returning id into v_workout_id;

  return json_build_object(
    'success', true,
    'message', 'Workout created successfully',
    'workout_id', v_workout_id,
    'workout_name', workout_name,
    'is_active', make_active
  );
exception
  when others then
    return json_build_object(
      'success', false,
      'error', 'Failed to create workout',
      'details', SQLERRM
    );
end;
$$ language plpgsql security definer;

comment on function create_workout is 'Creates a new workout plan with validation. Parameters: workout_name (required, text), workout_description (optional, text), workout_days (REQUIRED, JSONB object with day names as keys and exercise arrays as values), make_active (optional, boolean to set as active workout).';

-- =====================================================
-- GRANT PERMISSIONS
-- =====================================================
-- Allow authenticated users to create workouts
-- Adjust based on your authentication setup

-- Example: grant execute on function create_workout to authenticated;
-- Uncomment and adjust role as needed for your auth setup