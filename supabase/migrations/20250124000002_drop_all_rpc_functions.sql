-- =====================================================
-- Drop all RPC functions and old flat tables
-- =====================================================
-- Remove all user-defined functions that are no longer needed
-- and drop the old workouts_flat and sessions_flat tables

drop table if exists workouts_flat cascade;
drop table if exists sessions_flat cascade;

drop function if exists create_workout_from_json(jsonb) cascade;
drop function if exists delete_set(text, date, text, int) cascade;
drop function if exists get_exercise_history_flat(text, int, text) cascade;
drop function if exists get_exercises_for_day_flat(text, text) cascade;
drop function if exists get_session_sets_flat(text, date) cascade;
drop function if exists get_todays_exercises_flat() cascade;
drop function if exists get_todays_session() cascade;
drop function if exists get_workout_summary_flat(text, date) cascade;
drop function if exists log_set(text, date, text, int, int, numeric, text) cascade;
drop function if exists log_multiple_sets(text, date, jsonb, text) cascade;
drop function if exists set_active_workout(text) cascade;
drop function if exists update_session_notes(text, date, text) cascade;
drop function if exists update_set(text, date, text, int, int, numeric) cascade;
drop function if exists update_sessions_flat_updated_at() cascade;
drop function if exists update_sessions_updated_at() cascade;
drop function if exists update_workouts_flat_updated_at() cascade;
drop function if exists update_workouts_updated_at() cascade;
drop function if exists update_updated_at_column() cascade;
