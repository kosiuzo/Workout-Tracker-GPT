-- =====================================================
-- Drop JSON-Only RPC Functions
-- =====================================================
-- Remove functions that ONLY work with the old JSON-based
-- workouts and sessions tables (JSONB days/entries columns)
--
-- These functions cannot operate with the new flat table
-- architecture and should be replaced with flat-table versions
-- =====================================================

-- =====================================================
-- 1. DROP WORKOUT DAY MANIPULATION FUNCTIONS
-- =====================================================
-- These functions manipulate JSONB days column structure

drop function if exists add_exercise_to_day(uuid, text, text, int, int, int, text, text) cascade;
drop function if exists remove_exercise_from_day(uuid, text, text) cascade;
drop function if exists update_workout_day_weight(uuid, text, text, int) cascade;

-- =====================================================
-- 2. DROP SESSION ENTRY MANIPULATION FUNCTIONS
-- =====================================================
-- These functions manipulate JSONB entries column structure

drop function if exists update_entry_weight(uuid, text, int, int) cascade;
drop function if exists update_entry_reps(uuid, text, int, int) cascade;

-- =====================================================
-- 3. DROP WORKOUT CREATION FUNCTION
-- =====================================================
-- Creates workouts with empty JSONB days structure

drop function if exists create_workout(text, jsonb, text, boolean) cascade;

-- =====================================================
-- 4. DROP WORKOUT RETRIEVAL FUNCTIONS
-- =====================================================
-- These functions read from JSONB days structure

drop function if exists get_active_workout() cascade;
drop function if exists get_workout_for_day(text, uuid) cascade;

-- =====================================================
-- VERIFICATION
-- =====================================================

select '=== DROPPED JSON-ONLY FUNCTIONS ===' as status;

select
  p.proname as function_name,
  'STILL EXISTS - NOT DROPPED' as status
from pg_proc p
join pg_namespace n on p.pronamespace = n.oid
where n.nspname = 'public'
  and p.prokind = 'f'
  and p.proname in (
    'add_exercise_to_day',
    'remove_exercise_from_day',
    'update_workout_day_weight',
    'update_entry_weight',
    'update_entry_reps',
    'create_workout',
    'get_active_workout',
    'get_workout_for_day'
  );

select '=== MIGRATION COMPLETE ===' as status;
select 'All JSON-only functions have been removed.' as message;
