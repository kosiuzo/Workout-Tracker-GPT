-- =====================================================
-- Workout Tracker GPT v1.0 - Create Workout RPC
-- =====================================================
-- RPC function for creating new workout plans
-- =====================================================

-- =====================================================
-- CREATE_WORKOUT
-- =====================================================
-- Creates a new workout plan with validation and optional activation
-- Ensures data integrity and consistent response format

create or replace function create_workout(
  workout_name text,
  workout_description text default null,
  workout_days jsonb default '{}'::jsonb,
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

  -- Check for duplicate name
  if exists(select 1 from workouts where name = workout_name) then
    return json_build_object(
      'success', false,
      'error', 'A workout with this name already exists',
      'duplicate_name', workout_name
    );
  end if;

  -- Validate days structure (ensure it's a valid JSON object)
  if jsonb_typeof(workout_days) != 'object' then
    return json_build_object(
      'success', false,
      'error', 'Workout days must be a valid JSON object'
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

comment on function create_workout is 'Creates a new workout plan with validation. Parameters: workout_name (required), workout_description (optional), workout_days (JSONB object with day names as keys), make_active (boolean to set as active workout).';

-- =====================================================
-- GRANT PERMISSIONS
-- =====================================================
-- Allow authenticated users to create workouts
-- Adjust based on your authentication setup

-- Example: grant execute on function create_workout to authenticated;
-- Uncomment and adjust role as needed for your auth setup
