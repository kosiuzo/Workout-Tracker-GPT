-- =====================================================
-- Update GET_ACTIVE_WORKOUT to include current day
-- =====================================================
-- This helps ChatGPT which has issues determining the current date.
-- The function now returns the current day of the week (e.g., "monday")
-- based on the server's current date/time.

create or replace function get_active_workout()
returns json as $$
declare
  v_workout json;
  v_current_day text;
begin
  -- Get the current day of the week in lowercase (e.g., "monday", "tuesday")
  -- Use Eastern Time (America/New_York) instead of UTC
  -- PostgreSQL to_char with 'Day' returns the day name with padding
  -- We use trim and lower to clean it up
  v_current_day := lower(trim(to_char(current_timestamp at time zone 'America/New_York', 'Day')));

  select to_json(w.*)
  into v_workout
  from workouts w
  where w.is_active = true
  limit 1;

  if v_workout is null then
    return json_build_object(
      'success', false,
      'message', 'No active workout found',
      'current_day', v_current_day
    );
  end if;

  return json_build_object(
    'success', true,
    'workout', v_workout,
    'current_day', v_current_day
  );
end;
$$ language plpgsql security definer;

comment on function get_active_workout is 'Returns the currently active workout with all details and the current day of the week to help ChatGPT determine today''s workout.';

-- =====================================================
-- GET_TODAYS_WORKOUT
-- =====================================================
-- Convenience function that returns ONLY today's workout exercises.
-- This is a simple wrapper around get_workout_for_day that uses
-- the current day automatically, perfect for ChatGPT to answer
-- "What's my workout today?" with a single API call.

create or replace function get_todays_workout()
returns json as $$
declare
  v_current_day text;
begin
  -- Get the current day of the week in lowercase using Eastern Time
  v_current_day := lower(trim(to_char(current_timestamp at time zone 'America/New_York', 'Day')));

  -- Call get_workout_for_day with current day and no specific workout (uses active)
  return get_workout_for_day(v_current_day, null);
end;
$$ language plpgsql security definer;

comment on function get_todays_workout is 'Convenience function that returns today''s workout from the active workout plan. Combines get_workout_for_day with automatic current day detection.';
