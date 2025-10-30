-- =====================================================
-- Workout Tracker GPT - Update Workout Validation
-- =====================================================
-- Updates create_workout to require workout_days
-- Adds delete_workout functionality
-- =====================================================

-- =====================================================
-- UPDATE CREATE_WORKOUT
-- =====================================================
-- Remove default for workout_days and add validation
-- to ensure workout_days is provided and not empty

create or replace function create_workout(
  workout_name text,
  workout_description text default null,
  workout_days jsonb,  -- Removed default value - now required
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

  -- Validate workout_days is provided
  if workout_days is null then
    return json_build_object(
      'success', false,
      'error', 'Workout days are required. Please provide workout_days as a JSON object.'
    );
  end if;

  -- Validate days structure (ensure it's a valid JSON object)
  if jsonb_typeof(workout_days) != 'object' then
    return json_build_object(
      'success', false,
      'error', 'Workout days must be a valid JSON object'
    );
  end if;

  -- Validate that workout_days is not empty
  if workout_days = '{}'::jsonb then
    return json_build_object(
      'success', false,
      'error', 'Workout days cannot be empty. Please provide at least one day with exercises.'
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

comment on function create_workout is 'Creates a new workout plan with validation. Parameters: workout_name (required), workout_description (optional), workout_days (required JSONB object with day names as keys), make_active (boolean to set as active workout).';

-- =====================================================
-- DELETE_WORKOUT
-- =====================================================
-- Deletes a workout plan by UUID
-- Prevents deletion of the active workout

create or replace function delete_workout(
  workout_uuid uuid
)
returns json as $$
declare
  v_workout_name text;
  v_is_active boolean;
begin
  -- Validate workout_uuid is provided
  if workout_uuid is null then
    return json_build_object(
      'success', false,
      'error', 'Workout UUID is required'
    );
  end if;

  -- Check if workout exists and get details
  select name, is_active into v_workout_name, v_is_active
  from workouts
  where id = workout_uuid;

  if v_workout_name is null then
    return json_build_object(
      'success', false,
      'error', 'Workout not found',
      'workout_uuid', workout_uuid
    );
  end if;

  -- Prevent deletion of active workout
  if v_is_active then
    return json_build_object(
      'success', false,
      'error', 'Cannot delete the active workout. Please set another workout as active first.',
      'workout_name', v_workout_name
    );
  end if;

  -- Delete the workout
  delete from workouts where id = workout_uuid;

  return json_build_object(
    'success', true,
    'message', 'Workout deleted successfully',
    'workout_name', v_workout_name
  );
exception
  when others then
    return json_build_object(
      'success', false,
      'error', 'Failed to delete workout',
      'details', SQLERRM
    );
end;
$$ language plpgsql security definer;

comment on function delete_workout is 'Deletes a workout plan by UUID. Cannot delete the active workout. Parameters: workout_uuid (required UUID of the workout to delete).';

-- =====================================================
-- GRANT PERMISSIONS
-- =====================================================
-- Allow authenticated users to create and delete workouts
-- Uncomment and adjust role as needed for your auth setup

-- grant execute on function create_workout to authenticated;
-- grant execute on function delete_workout to authenticated;
