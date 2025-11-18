-- =====================================================
-- Remove ALL RPC Functions
-- =====================================================
-- Removes all RPC functions, keeping only table schemas
-- Direct REST API access will be used for all operations
-- =====================================================

-- Drop all RPC functions in order of dependencies

-- Drop progress/history functions
drop function if exists get_recent_progress(int, text) cascade;
drop function if exists get_recent_progress(int, uuid) cascade;
drop function if exists get_exercise_progress(text, int, text) cascade;
drop function if exists get_exercise_progress(text, int, uuid) cascade;
drop function if exists get_exercise_history_flat(text, int, text) cascade;

-- Drop workout planning functions
drop function if exists get_active_workout() cascade;
drop function if exists get_workout_for_day(text, uuid) cascade;
drop function if exists get_todays_exercises_flat() cascade;
drop function if exists get_exercises_for_day_flat(text, text) cascade;
drop function if exists set_active_workout(text) cascade;

-- Drop session management functions
drop function if exists get_todays_session() cascade;
drop function if exists get_session_sets_flat(text, date) cascade;
drop function if exists get_workout_summary_flat(text, date) cascade;

-- Drop set logging functions
drop function if exists log_set(text, date, text, int, int, numeric, text) cascade;
drop function if exists log_multiple_sets(text, date, jsonb, text) cascade;
drop function if exists log_workout_day(jsonb, text, text, date, text) cascade;
drop function if exists update_set(text, date, text, int, int, numeric) cascade;
drop function if exists delete_set(text, date, text, int) cascade;
drop function if exists update_session_notes(text, date, text) cascade;

-- Drop workout management functions
drop function if exists set_active_workout(uuid) cascade;
drop function if exists create_workout(text, text, jsonb, boolean) cascade;
drop function if exists create_workout_from_json(jsonb) cascade;
drop function if exists add_exercise_to_day(uuid, text, text, int, int, int, text, text) cascade;
drop function if exists remove_exercise_from_day(uuid, text, text) cascade;
drop function if exists update_workout_day_weight(uuid, text, text, int) cascade;
drop function if exists update_entry_reps(uuid, text, int, int) cascade;
drop function if exists update_entry_weight(uuid, text, int, numeric) cascade;
drop function if exists get_todays_workout() cascade;

-- Drop aggregation functions
drop function if exists calc_exercise_history(date) cascade;
drop function if exists calc_workout_history(date) cascade;
drop function if exists calc_all_history(date) cascade;

-- =====================================================
-- Summary
-- =====================================================
-- All RPC functions have been removed.
-- The system now uses direct REST API access via Supabase PostgREST.
--
-- Remaining tables (schema only):
-- - workouts_flat (workout templates)
-- - sessions_flat (logged workout sets)
-- - exercise_history (aggregated exercise stats)
-- - workout_history (aggregated workout stats)
--
-- Users interact directly with tables via REST endpoints
