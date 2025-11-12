# Complete RPC Functions List - Workout Tracker GPT

## Summary
**Total Functions**: 26 RPC functions + 3 trigger functions
**Status**: ✅ All tested and working
**Last Updated**: 2025-11-11

---

## Aggregation Functions (History Calculations)

### 1. **calc_exercise_history** ✅
- **Parameters**: `date_override date (default: current_date)`
- **Returns**: JSON
- **Description**: Aggregates session_flat data into exercise_history for a specific date using workout_name
- **Usage**: Called by cron job or manually to populate exercise_history table
- **Test Result**: ✅ PASS - Returns 0 or more exercise records depending on date

### 2. **calc_workout_history** ✅
- **Parameters**: `date_override date (default: current_date)`
- **Returns**: JSON
- **Description**: Rolls up exercise_history into workout_history for a specific date using workout_name
- **Usage**: Must be run after calc_exercise_history
- **Test Result**: ✅ PASS - Returns 0 or more workout records depending on date

### 3. **calc_all_history** ✅
- **Parameters**: `date_override date (default: current_date)`
- **Returns**: JSON
- **Description**: Orchestrates both calc_exercise_history and calc_workout_history in sequence
- **Usage**: Single function to calculate all history for a date
- **Test Result**: ✅ PASS - Returns combined results from both functions

---

## Progress/History Retrieval Functions

### 4. **get_recent_progress** ✅
- **Parameters**: `days_back int (default: 7)`, `workout_name_param text (default: null)`
- **Returns**: JSON
- **Description**: Returns workout history for the last N days, optionally filtered by workout_name
- **Usage**: Get recent workout summaries
- **Test Result**: ✅ PASS - Returns workout history records with volume/sets/reps stats

### 5. **get_exercise_progress** ✅
- **Parameters**: `exercise_name_param text`, `days_back int (default: 30)`, `workout_name_param text (default: null)`
- **Returns**: JSON
- **Description**: Returns history for a specific exercise over time, optionally filtered by workout_name
- **Usage**: Track progress on specific exercises
- **Test Result**: ✅ PASS - Returns exercise history with aggregated stats

### 6. **get_exercise_history_flat** ✅
- **Parameters**: `exercise_name_param text`, `days_back int (default: 30)`, `workout_name_param text (default: null)`
- **Returns**: JSON
- **Description**: Returns detailed set-by-set history for a specific exercise from sessions_flat
- **Usage**: Detailed exercise history with per-set and summary data
- **Test Result**: ✅ PASS (FIXED) - Returns detailed and summary history data

---

## Workout Planning Functions

### 7. **get_active_workout** ✅
- **Parameters**: None
- **Returns**: JSON
- **Description**: Returns the currently active workout with all details including days and exercises
- **Usage**: Get the user's current workout plan
- **Test Result**: ✅ PASS - Returns full workout with JSONB days structure

### 8. **get_todays_exercises_flat** ✅
- **Parameters**: None
- **Returns**: JSON
- **Description**: Returns today's workout exercises from workouts_flat table
- **Usage**: Get exercises to perform today
- **Test Result**: ✅ PASS - Returns exercises for current day or error if no active workout

### 9. **get_exercises_for_day_flat** ✅
- **Parameters**: `day_name_param text`, `workout_name_param text (default: null)`
- **Returns**: JSON
- **Description**: Returns exercises for a specific day from workouts_flat
- **Usage**: Get exercises for any day of the week
- **Test Result**: ✅ PASS - Returns structured exercise data

### 10. **get_workout_for_day** ✅
- **Parameters**: `day_name text`, `workout_uuid uuid (default: null)`
- **Returns**: JSON
- **Description**: Returns workout plan for a specific day (uses active workout by default)
- **Usage**: Legacy function - get workout plan for specific day
- **Test Result**: ✅ PASS - Returns JSONB days data

### 11. **set_active_workout** ✅
- **Parameters**: `workout_uuid uuid`
- **Returns**: JSON
- **Description**: Activates a workout plan and deactivates all others
- **Usage**: Switch active workout
- **Test Result**: ✅ PASS - Returns success status

---

## Session Management Functions

### 12. **get_todays_session** ✅
- **Parameters**: None
- **Returns**: JSON
- **Description**: Returns today's workout session with all sets from the active workout
- **Usage**: Get today's session data
- **Test Result**: ✅ PASS - Returns session with sets or error if no session

### 13. **get_session_sets_flat** ✅
- **Parameters**: `workout_name_param text`, `session_date_param date`
- **Returns**: JSON
- **Description**: Returns all sets for a session from sessions_flat table
- **Usage**: Get session data for specific date
- **Test Result**: ✅ PASS - Returns all sets with exercise/set/reps/weight data

### 14. **get_workout_summary_flat** ✅
- **Parameters**: `workout_name_param text`, `session_date_param date`
- **Returns**: JSON
- **Description**: Returns summary statistics for a workout session grouped by exercise
- **Usage**: Get session summary with exercise aggregations
- **Test Result**: ✅ PASS - Returns summary with total sets/reps/volume per exercise

---

## Set Logging Functions

### 15. **log_set** ✅
- **Parameters**: `workout_name_param text`, `session_date_param date`, `exercise_name_param text`, `set_number_param int`, `reps_param int`, `weight_param numeric`, `session_notes_param text (default: null)`
- **Returns**: JSON
- **Description**: Logs a single set to sessions_flat (creates or updates)
- **Usage**: Log individual sets during workout
- **Test Result**: ✅ PASS - Successfully logs sets and returns set data

### 16. **log_multiple_sets** ✅
- **Parameters**: `workout_name_param text`, `session_date_param date`, `sets_data jsonb`, `session_notes_param text (default: null)`
- **Returns**: JSON
- **Description**: Logs multiple sets at once from JSON array
- **Usage**: Batch log sets
- **Test Result**: ✅ PASS - Accepts JSON array format

### 17. **update_set** ✅
- **Parameters**: `workout_name_param text`, `session_date_param date`, `exercise_name_param text`, `set_number_param int`, `reps_param int (default: null)`, `weight_param numeric (default: null)`
- **Returns**: JSON
- **Description**: Updates reps and/or weight for a specific set
- **Usage**: Modify logged sets
- **Test Result**: ✅ PASS - Returns updated set data

### 18. **delete_set** ✅
- **Parameters**: `workout_name_param text`, `session_date_param date`, `exercise_name_param text`, `set_number_param int`
- **Returns**: JSON
- **Description**: Deletes a specific set from a session
- **Usage**: Remove logged sets
- **Test Result**: ✅ PASS - Removes sets and returns success

### 19. **update_session_notes** ✅
- **Parameters**: `workout_name_param text`, `session_date_param date`, `session_notes_param text`
- **Returns**: JSON
- **Description**: Updates session notes for a workout on a specific date
- **Usage**: Add/update session notes
- **Test Result**: ✅ PASS - Returns updated count

---

## Workout Management Functions

### 20. **create_workout** ✅
- **Parameters**: `workout_name text`, `workout_days jsonb`, `workout_description text`, `make_active boolean`
- **Returns**: JSON
- **Description**: Creates a new workout plan
- **Usage**: Create new workout
- **Test Result**: ✅ PASS - Creates workout and populates workouts_flat

### 21. **add_exercise_to_day** ✅
- **Parameters**: `workout_uuid uuid`, `day_name text`, `exercise_name text`, `sets int`, `reps int`, `weight int`, `superset_group text`, `notes text`
- **Returns**: JSON
- **Description**: Adds an exercise to a specific day in a workout
- **Usage**: Add exercises to workout plan
- **Test Result**: ✅ PASS - Returns success/error

### 22. **remove_exercise_from_day** ✅
- **Parameters**: `workout_uuid uuid`, `day_name text`, `exercise_name text`
- **Returns**: JSON
- **Description**: Removes an exercise from a specific day
- **Usage**: Remove exercises from workout plan
- **Test Result**: ✅ PASS - Returns success/error

---

## Workout Plan Update Functions

### 23. **update_workout_day_weight** ✅
- **Parameters**: `workout_uuid uuid`, `day_name text`, `exercise_name text`, `new_weight int`
- **Returns**: JSON
- **Description**: Updates weight for an exercise in a workout plan
- **Usage**: Adjust planned weight
- **Test Result**: ✅ PASS - Returns updated exercise data

### 24. **update_entry_reps** ✅
- **Parameters**: `session_uuid uuid`, `exercise_name text`, `set_number int`, `new_reps int`
- **Returns**: JSON
- **Description**: Updates reps for a session entry
- **Usage**: Update logged reps
- **Test Result**: ✅ PASS - Returns updated data

### 25. **update_entry_weight** ✅
- **Parameters**: `session_uuid uuid`, `exercise_name text`, `set_number int`, `new_weight int`
- **Returns**: JSON
- **Description**: Updates weight for a session entry
- **Usage**: Update logged weight
- **Test Result**: ✅ PASS - Returns updated data

### 26. **get_todays_workout** ✅
- **Parameters**: None
- **Returns**: JSON
- **Description**: Returns today's workout details
- **Usage**: Get current day workout
- **Test Result**: ✅ PASS - Returns workout for today

---

## Trigger Functions (Automatic)

### T1. **update_workouts_flat_updated_at** ✅ TRIGGER
- **Event**: UPDATE on workouts_flat
- **Action**: Automatically updates updated_at timestamp
- **Status**: Active

### T2. **update_sessions_flat_updated_at** ✅ TRIGGER
- **Event**: UPDATE on sessions_flat
- **Action**: Automatically updates updated_at timestamp
- **Status**: Active

### T3. **update_updated_at_column** ✅ TRIGGER
- **Event**: UPDATE on various tables
- **Action**: Automatically updates updated_at timestamp
- **Status**: Active

---

## Key Features

✅ All functions use `workout_name` (text) for flat table correlation
✅ Functions support optional filtering by workout_name
✅ Aggregate functions calculate history from flat tables
✅ Progress tracking functions return JSON with full statistics
✅ Session management works directly with sessions_flat
✅ Error handling with descriptive messages
✅ Idempotent aggregation functions
✅ Set-level and workout-level aggregations available
✅ Automatic timestamp maintenance via triggers

---

## Testing Summary

| Category | Count | Status |
|----------|-------|--------|
| Aggregation | 3 | ✅ All Pass |
| History/Progress | 3 | ✅ All Pass |
| Workout Planning | 5 | ✅ All Pass |
| Session Management | 3 | ✅ All Pass |
| Set Logging | 5 | ✅ All Pass |
| Workout Management | 3 | ✅ All Pass |
| Workout Updates | 3 | ✅ All Pass |
| **Total RPC** | **26** | **✅ ALL PASS** |
| Triggers | 3 | ✅ All Active |

---

## Architecture Notes

- All functions use PostgreSQL security definer
- All return JSON for API compatibility
- History tables (exercise_history, workout_history) use workout_name (text) as key
- Session data stored in sessions_flat with denormalized workout_name
- Workout plans stored in workouts_flat with denormalized structure
- Aggregation functions are idempotent (safe to run multiple times)
- Timestamps automatically maintained by triggers

