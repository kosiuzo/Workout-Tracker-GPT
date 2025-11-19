-- =====================================================
-- Fix set_active_workout RPC Function
-- =====================================================
-- Issue: UPDATE statement requires WHERE clause
-- Fix: Add explicit WHERE clause to the deactivation UPDATE

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

  -- Deactivate all workouts (with explicit WHERE clause)
  update workouts
  set workout_is_active = false
  where workout_is_active = true;

  -- Activate the specified workout
  update workouts
  set workout_is_active = true
  where workout_name = p_workout_name;

  return jsonb_build_object(
    'success', true,
    'message', 'Workout activated successfully',
    'workout_name', p_workout_name,
    'is_active', true
  );
end;
$$ language plpgsql;
