# Current RPC Functions Inventory

## Summary
**Total Functions**: 21  
**Status**: All compatible with flat table architecture  
**Last Updated**: November 11, 2025

---

## Category 1: Aggregation Functions (3)

### ✅ `calc_exercise_history(date_override date)`
**Purpose**: Aggregate exercise statistics from sessions_flat for a specific date  
**Input**: `date_override` (default: today)  
**Output**: JSON with success status and rows affected  
**Uses**: `sessions_flat`, `workouts_flat`, `exercise_history`  
**Key**: Uses `workout_name` (text) instead of UUID  
**Idempotent**: Yes (UPSERT on conflict)

### ✅ `calc_workout_history(date_override date)`
**Purpose**: Aggregate workout statistics from exercise_history for a specific date  
**Input**: `date_override` (default: today)  
**Output**: JSON with success status and rows affected  
**Uses**: `exercise_history`, `workout_history`  
**Key**: Uses `workout_name` (text) instead of UUID  
**Idempotent**: Yes (UPSERT on conflict)  
**Dependency**: Run after `calc_exercise_history()`

### ✅ `calc_all_history(date_override date)`
**Purpose**: Orchestrate complete aggregation (exercise → workout)  
**Input**: `date_override` (default: today)  
**Output**: JSON with both exercise and workout aggregation results  
**Calls**: `calc_exercise_history()` then `calc_workout_history()`  
**Idempotent**: Yes

---

## Category 2: Flat Table Query Functions (7)

### ✅ `get_todays_exercises_flat()`
**Purpose**: Get today's workout exercises from active workout  
**Input**: None (uses current date, Eastern Time)  
**Output**: JSON with exercises for today's day of week  
**Uses**: `workouts_flat`  
**Current Day**: Determined by `to_char(current_timestamp at time zone 'America/New_York', 'Day')`  
**Returns**: Exercise list with order, name, sets, reps, weight, superset_group, notes

### ✅ `get_exercises_for_day_flat(day_name text, workout_name text DEFAULT NULL)`
**Purpose**: Get exercises for a specific day from a workout  
**Input**:  
  - `day_name_param` (Monday, Tuesday, etc.)  
  - `workout_name_param` (optional, defaults to active)  
**Output**: JSON with exercises for specified day  
**Uses**: `workouts_flat`  
**Returns**: Exercise list for the day

### ✅ `get_session_sets_flat(workout_name text, session_date date)`
**Purpose**: Get all sets from a specific session  
**Input**:  
  - `workout_name_param`  
  - `session_date_param`  
**Output**: JSON with session notes and all sets  
**Uses**: `sessions_flat`  
**Returns**: Sets ordered by exercise name and set number

### ✅ `get_workout_summary_flat(workout_name text, session_date date)`
**Purpose**: Get summary of a workout session grouped by exercise  
**Input**:  
  - `workout_name_param`  
  - `session_date_param`  
**Output**: JSON with exercise summaries (sets, reps, volume, max/avg weight)  
**Uses**: `sessions_flat`  
**Calculation**: Aggregates by exercise with stats

### ✅ `get_exercise_history_flat(exercise_name text, days_back int DEFAULT 30, workout_name text DEFAULT NULL)`
**Purpose**: Get detailed and summary history for an exercise  
**Input**:  
  - `exercise_name_param` (required)  
  - `days_back` (default: 30)  
  - `workout_name_param` (optional, filters to specific workout)  
**Output**: JSON with detailed history and date-grouped summaries  
**Uses**: `sessions_flat`  
**Returns**: Detailed sets + summary statistics by date

### ✅ `get_todays_session()`
**Purpose**: Get today's session for active workout  
**Input**: None (uses current date, Eastern Time)  
**Output**: JSON with today's session and all sets  
**Uses**: `workouts_flat`, `sessions_flat`  
**Calls**: `get_session_sets_flat()`  
**Current Date**: Eastern Time zone

### ✅ `get_todays_workout()`
**Purpose**: Get today's workout template for active workout  
**Input**: None (uses current date, Eastern Time)  
**Output**: JSON with today's workout exercises  
**Uses**: `workouts_flat`  
**Note**: May call `get_todays_exercises_flat()` or be separate

---

## Category 3: Set Logging Functions (5)

### ✅ `log_set(workout_name text, session_date date, exercise_name text, set_number int, reps int, weight numeric, session_notes text DEFAULT NULL)`
**Purpose**: Log a single set for a session  
**Input**:  
  - `workout_name_param`  
  - `session_date_param`  
  - `exercise_name_param`  
  - `set_number_param` (1-indexed)  
  - `reps_param`  
  - `weight_param`  
  - `session_notes_param` (optional)  
**Output**: JSON with logged set details  
**Uses**: `sessions_flat`  
**Idempotent**: Yes (UPSERT replaces existing set)  
**Validation**: Exercise name, reps > 0, weight >= 0

### ✅ `log_multiple_sets(workout_name text, session_date date, sets_data jsonb, session_notes text DEFAULT NULL)`
**Purpose**: Log multiple sets at once for efficiency  
**Input**:  
  - `workout_name_param`  
  - `session_date_param`  
  - `sets_data` (JSON array with exercise, set, reps, weight)  
  - `session_notes_param` (optional)  
**Output**: JSON with count of sets logged  
**Uses**: `sessions_flat` (calls `log_set()` for each)  
**Format**: 
```json
[
  {"exercise": "Bench Press", "set": 1, "reps": 8, "weight": 185},
  {"exercise": "Bench Press", "set": 2, "reps": 8, "weight": 185}
]
```

### ✅ `update_set(workout_name text, session_date date, exercise_name text, set_number int, reps int DEFAULT NULL, weight numeric DEFAULT NULL)`
**Purpose**: Update a set's reps and/or weight  
**Input**:  
  - `workout_name_param`  
  - `session_date_param`  
  - `exercise_name_param`  
  - `set_number_param`  
  - `reps_param` (optional, kept if NULL)  
  - `weight_param` (optional, kept if NULL)  
**Output**: JSON with updated set details  
**Uses**: `sessions_flat`  
**Logic**: Only updates provided fields, keeps others

### ✅ `delete_set(workout_name text, session_date date, exercise_name text, set_number int)`
**Purpose**: Delete a specific set from a session  
**Input**:  
  - `workout_name_param`  
  - `session_date_param`  
  - `exercise_name_param`  
  - `set_number_param`  
**Output**: JSON with success/failure  
**Uses**: `sessions_flat`  
**Return**: Error if set not found

### ✅ `update_session_notes(workout_name text, session_date date, session_notes text)`
**Purpose**: Update notes for an entire session  
**Input**:  
  - `workout_name_param`  
  - `session_date_param`  
  - `session_notes_param`  
**Output**: JSON with rows updated and notes  
**Uses**: `sessions_flat`  
**Updates**: All rows for this session with new notes

---

## Category 4: Progress Tracking Functions (3)

### ✅ `get_recent_progress(days_back int DEFAULT 7, workout_name text DEFAULT NULL)`
**Purpose**: Get workout history for past N days  
**Input**:  
  - `days_back` (default: 7)  
  - `workout_name_param` (optional, filters to specific workout)  
**Output**: JSON with workout_history records  
**Uses**: `workout_history`  
**Key**: Uses `workout_name` (text) instead of UUID  
**Ordered**: By date descending

### ✅ `get_exercise_progress(exercise_name text, days_back int DEFAULT 30, workout_name text DEFAULT NULL)`
**Purpose**: Get exercise history with progression over time  
**Input**:  
  - `exercise_name_param` (required)  
  - `days_back` (default: 30)  
  - `workout_name_param` (optional, filters to specific workout)  
**Output**: JSON with exercise_history records  
**Uses**: `exercise_history`  
**Key**: Uses `workout_name` (text) instead of UUID  
**Ordered**: By date descending  
**Shows**: Sets, reps, volume, max/avg weight progression

---

## Category 5: Utility Functions (3)

### ✅ `set_active_workout(workout_uuid uuid)`
**Purpose**: Activate one workout and deactivate all others  
**Input**: `workout_uuid` (UUID of workout to activate)  
**Output**: JSON with success status and workout details  
**Uses**: `workouts` table (still UUID-based)  
**Side Effects**: Deactivates all other workouts  
**⚠️ Note**: Last remaining function using UUID; consider updating to use workout_name

---

## Hidden Trigger Functions (3)

These functions maintain database integrity:

### ✅ `update_workouts_flat_updated_at()`
**Purpose**: Auto-update `updated_at` timestamp on workouts_flat changes  
**Trigger**: `update_workouts_flat_updated_at` on workouts_flat  
**Type**: BEFORE UPDATE trigger  
**Action**: Sets `new.updated_at = now()`

### ✅ `update_sessions_flat_updated_at()`
**Purpose**: Auto-update `updated_at` timestamp on sessions_flat changes  
**Trigger**: `update_sessions_flat_updated_at` on sessions_flat  
**Type**: BEFORE UPDATE trigger  
**Action**: Sets `new.updated_at = now()`

### ✅ `update_updated_at_column()`
**Purpose**: Generic trigger function for timestamp updates  
**Type**: Reusable BEFORE UPDATE trigger  
**Used By**: Other timestamp maintenance triggers

---

## Function Statistics

| Category | Count | Status |
|----------|-------|--------|
| Aggregation | 3 | ✅ Flat-table compatible |
| Flat table queries | 7 | ✅ Flat-table compatible |
| Set logging | 5 | ✅ Flat-table compatible |
| Progress tracking | 3 | ✅ Flat-table compatible |
| Utility | 1 | ⚠️ UUID-based (needs update) |
| Triggers | 3 | ✅ Trigger functions |
| **TOTAL** | **21** | ✅ All functional |

---

## Dependencies Between Functions

```
User Action
├─ Log set → log_set() → sessions_flat
├─ Log multiple sets → log_multiple_sets() → log_set() → sessions_flat
├─ Update set → update_set() → sessions_flat
├─ Delete set → delete_set() → sessions_flat
├─ Update session notes → update_session_notes() → sessions_flat
│
├─ Get today's exercises → get_todays_exercises_flat() → workouts_flat
├─ Get day exercises → get_exercises_for_day_flat() → workouts_flat
├─ Get today's session → get_todays_session() → sessions_flat
├─ Get today's workout → get_todays_workout() → workouts_flat
│
├─ Get session sets → get_session_sets_flat() → sessions_flat
├─ Get workout summary → get_workout_summary_flat() → sessions_flat
├─ Get exercise history → get_exercise_history_flat() → sessions_flat
│
├─ Get recent progress → get_recent_progress() → workout_history
├─ Get exercise progress → get_exercise_progress() → exercise_history
│
└─ Aggregate history:
   calc_exercise_history() → sessions_flat, workouts_flat → exercise_history
   ↓
   calc_workout_history() → exercise_history → workout_history
   ↓
   calc_all_history() → orchestrates both
```

---

## Aggregation Schedule

For optimal performance, run aggregation in this order:

1. **First**: `calc_exercise_history(date)` - Aggregate set-level data
2. **Second**: `calc_workout_history(date)` - Aggregate to workout level
3. **Or use**: `calc_all_history(date)` - Runs both automatically

Suggested schedule: Run daily via cron at 11 PM (after workout logging closes)

---

## Notes

- ✅ **No JSON dependencies**: All functions work with flat tables
- ✅ **All text-keyed**: Functions use `workout_name` (text) instead of UUID
- ⚠️ **One exception**: `set_active_workout()` still uses UUID (legacy)
- ✅ **Idempotent aggregations**: Safe to run multiple times
- ✅ **Eastern Time awareness**: Date functions use `America/New_York` timezone

