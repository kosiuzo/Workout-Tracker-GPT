# Flat Table RPC Functions

## Overview
This document describes RPC functions for working with the flattened `workouts_flat` and `sessions_flat` tables. These functions simplify workout logging and querying by working with denormalized data structures.

## Table of Contents
- [Workout Query Functions](#workout-query-functions)
- [Session Management Functions](#session-management-functions)
- [Set Logging Functions](#set-logging-functions)
- [History and Analytics Functions](#history-and-analytics-functions)

---

## Workout Query Functions

### 1. `get_todays_exercises_flat()`
Returns today's workout exercises from the active workout plan using the flattened table.

**Parameters:** None

**Returns:**
```json
{
  "success": true,
  "workout_id": "uuid",
  "workout_name": "Push/Pull/Legs v1",
  "current_day": "monday",
  "exercises": [
    {
      "exercise_order": 0,
      "exercise_name": "Bench Press",
      "sets": 4,
      "reps": 8,
      "weight": 185,
      "superset_group": null,
      "notes": "Barbell, touch chest each rep"
    }
  ]
}
```

**Example:**
```sql
SELECT get_todays_exercises_flat();
```

**Use Case:** Perfect for ChatGPT to answer "What's my workout today?" with detailed exercise information.

---

### 2. `get_exercises_for_day_flat(day_name, workout_id?)`
Returns exercises for a specific day from the flattened table.

**Parameters:**
- `day_name` (text, required) - Day of the week (e.g., "monday", "tuesday")
- `workout_id` (uuid, optional) - Specific workout ID (defaults to active workout)

**Returns:**
```json
{
  "success": true,
  "workout_id": "uuid",
  "workout_name": "Push/Pull/Legs v1",
  "day": "monday",
  "exercises": [...]
}
```

**Example:**
```sql
-- Get exercises for Wednesday from active workout
SELECT get_exercises_for_day_flat('wednesday');

-- Get exercises from specific workout
SELECT get_exercises_for_day_flat('friday', 'workout-uuid-here');
```

---

## Session Management Functions

### 3. `start_session(date?, workout_id?, notes?)`
Creates a new workout session for a specific date.

**Parameters:**
- `date` (date, optional) - Session date (defaults to current date)
- `workout_id` (uuid, optional) - Workout ID (defaults to active workout)
- `notes` (text, optional) - Session notes

**Returns:**
```json
{
  "success": true,
  "message": "Session started successfully",
  "session_id": "uuid",
  "workout_id": "uuid",
  "workout_name": "Push/Pull/Legs v1",
  "date": "2025-01-06"
}
```

**Example:**
```sql
-- Start session for today
SELECT start_session();

-- Start session for specific date with notes
SELECT start_session('2025-01-05', null, 'Morning workout');
```

**Notes:**
- Prevents duplicate sessions for the same workout and date
- Returns error if session already exists

---

### 4. `get_todays_session()`
Returns today's workout session with all logged sets.

**Parameters:** None

**Returns:**
```json
{
  "success": true,
  "session_id": "uuid",
  "workout_id": "uuid",
  "workout_name": "Push/Pull/Legs v1",
  "date": "2025-01-06",
  "notes": "Great workout",
  "sets": [
    {
      "id": "uuid",
      "exercise_name": "Bench Press",
      "set_number": 1,
      "reps": 10,
      "weight": 185
    }
  ]
}
```

**Example:**
```sql
SELECT get_todays_session();
```

---

### 5. `get_session_sets_flat(session_id)`
Returns all sets for a specific session using the flat table.

**Parameters:**
- `session_id` (uuid, required) - Session ID

**Returns:**
```json
{
  "success": true,
  "session_id": "uuid",
  "workout_id": "uuid",
  "workout_name": "Push/Pull/Legs v1",
  "date": "2025-01-06",
  "notes": "Great workout",
  "sets": [...]
}
```

**Example:**
```sql
SELECT get_session_sets_flat('session-uuid-here');
```

---

### 6. `complete_session(session_id, final_notes?)`
Marks a session as complete and calculates exercise/workout history.

**Parameters:**
- `session_id` (uuid, required) - Session ID
- `final_notes` (text, optional) - Final notes to add/update

**Returns:**
```json
{
  "success": true,
  "message": "Session completed and history calculated",
  "session_id": "uuid",
  "date": "2025-01-06",
  "history_result": {...}
}
```

**Example:**
```sql
SELECT complete_session('session-uuid-here', 'Excellent session, felt strong');
```

**Notes:**
- Automatically calls `calc_all_history()` to update history tables
- Updates session notes if provided

---

## Set Logging Functions

### 7. `log_set(session_id, exercise_name, set_number, reps, weight)`
Logs a single set to a session. If a set with the same exercise and set number exists, it will be replaced.

**Parameters:**
- `session_id` (uuid, required) - Session ID
- `exercise_name` (text, required) - Exercise name
- `set_number` (int, required) - Set number (1, 2, 3, etc.)
- `reps` (int, required) - Number of reps performed
- `weight` (numeric, required) - Weight used

**Returns:**
```json
{
  "success": true,
  "message": "Set logged successfully",
  "session_id": "uuid",
  "exercise": "Bench Press",
  "set": 1,
  "reps": 10,
  "weight": 185
}
```

**Example:**
```sql
-- Log first set of bench press
SELECT log_set(
  'session-uuid-here',
  'Bench Press',
  1,
  10,
  185
);

-- Update/replace existing set
SELECT log_set(
  'session-uuid-here',
  'Bench Press',
  1,
  8,
  185
);
```

**Notes:**
- Automatically updates the `sessions_flat` table via trigger
- Replaces existing set if same exercise and set number
- Validates all inputs before logging

---

### 8. `log_multiple_sets(session_id, sets_data)`
Logs multiple sets at once for efficiency.

**Parameters:**
- `session_id` (uuid, required) - Session ID
- `sets_data` (jsonb, required) - Array of set objects

**Returns:**
```json
{
  "success": true,
  "message": "Logged 5 sets successfully",
  "session_id": "uuid",
  "sets_logged": 5
}
```

**Example:**
```sql
SELECT log_multiple_sets(
  'session-uuid-here',
  '[
    {"exercise": "Bench Press", "set": 1, "reps": 10, "weight": 185},
    {"exercise": "Bench Press", "set": 2, "reps": 9, "weight": 185},
    {"exercise": "Bench Press", "set": 3, "reps": 8, "weight": 185},
    {"exercise": "Incline Press", "set": 1, "reps": 10, "weight": 60},
    {"exercise": "Incline Press", "set": 2, "reps": 10, "weight": 60}
  ]'::jsonb
);
```

**Notes:**
- More efficient than calling `log_set()` multiple times
- Each set is validated independently

---

### 9. `update_set(session_id, exercise_name, set_number, reps?, weight?)`
Updates a specific set in a session. Only provided parameters will be updated.

**Parameters:**
- `session_id` (uuid, required) - Session ID
- `exercise_name` (text, required) - Exercise name
- `set_number` (int, required) - Set number
- `reps` (int, optional) - New reps value
- `weight` (numeric, optional) - New weight value

**Returns:**
```json
{
  "success": true,
  "message": "Set updated successfully",
  "session_id": "uuid",
  "exercise": "Bench Press",
  "set": 1
}
```

**Example:**
```sql
-- Update only reps
SELECT update_set(
  'session-uuid-here',
  'Bench Press',
  1,
  12,  -- new reps
  null -- keep existing weight
);

-- Update only weight
SELECT update_set(
  'session-uuid-here',
  'Bench Press',
  1,
  null, -- keep existing reps
  195   -- new weight
);

-- Update both
SELECT update_set(
  'session-uuid-here',
  'Bench Press',
  1,
  12,  -- new reps
  195  -- new weight
);
```

---

### 10. `delete_set(session_id, exercise_name, set_number)`
Deletes a specific set from a session.

**Parameters:**
- `session_id` (uuid, required) - Session ID
- `exercise_name` (text, required) - Exercise name
- `set_number` (int, required) - Set number

**Returns:**
```json
{
  "success": true,
  "message": "Set deleted successfully",
  "session_id": "uuid",
  "exercise": "Bench Press",
  "set": 3
}
```

**Example:**
```sql
SELECT delete_set(
  'session-uuid-here',
  'Bench Press',
  3
);
```

---

## History and Analytics Functions

### 11. `get_exercise_history_flat(exercise_name, days_back?, workout_id?)`
Returns detailed history for a specific exercise from the sessions_flat table.

**Parameters:**
- `exercise_name` (text, required) - Exercise name
- `days_back` (int, optional) - Number of days to look back (default: 30)
- `workout_id` (uuid, optional) - Filter by specific workout

**Returns:**
```json
{
  "success": true,
  "exercise": "Bench Press",
  "days_back": 30,
  "detailed_history": [
    {
      "date": "2025-01-06",
      "set_number": 1,
      "reps": 10,
      "weight": 185,
      "volume": 1850
    }
  ],
  "summary": [
    {
      "date": "2025-01-06",
      "total_sets": 4,
      "total_reps": 34,
      "total_volume": 6290,
      "max_weight": 185,
      "avg_weight": 185
    }
  ]
}
```

**Example:**
```sql
-- Get last 30 days of bench press
SELECT get_exercise_history_flat('Bench Press');

-- Get last 90 days
SELECT get_exercise_history_flat('Bench Press', 90);

-- Get history from specific workout
SELECT get_exercise_history_flat('Squat', 30, 'workout-uuid-here');
```

**Use Case:** Track progression, identify plateaus, analyze volume trends

---

### 12. `get_workout_summary_flat(session_id)`
Returns summary statistics for a workout session grouped by exercise.

**Parameters:**
- `session_id` (uuid, required) - Session ID

**Returns:**
```json
{
  "success": true,
  "session_id": "uuid",
  "workout_id": "uuid",
  "workout_name": "Push/Pull/Legs v1",
  "date": "2025-01-06",
  "notes": "Great workout",
  "summary": [
    {
      "exercise_name": "Bench Press",
      "total_sets": 4,
      "total_reps": 34,
      "total_volume": 6290,
      "max_weight": 185,
      "avg_weight": 185
    },
    {
      "exercise_name": "Incline Dumbbell Press",
      "total_sets": 3,
      "total_reps": 29,
      "total_volume": 1740,
      "max_weight": 60,
      "avg_weight": 60
    }
  ]
}
```

**Example:**
```sql
SELECT get_workout_summary_flat('session-uuid-here');
```

**Use Case:** Post-workout summary, volume tracking, progress verification

---

## Common Workflows

### Starting a New Workout
```sql
-- 1. Get today's exercises
SELECT get_todays_exercises_flat();

-- 2. Start a session
SELECT start_session();

-- 3. Log sets as you go
SELECT log_set('session-id', 'Bench Press', 1, 10, 185);
SELECT log_set('session-id', 'Bench Press', 2, 9, 185);
...

-- 4. Complete the session
SELECT complete_session('session-id', 'Great workout!');
```

### Checking Progress
```sql
-- View today's progress
SELECT get_todays_session();

-- Get summary
SELECT get_workout_summary_flat('session-id');

-- Check exercise progression
SELECT get_exercise_history_flat('Bench Press', 90);
```

### Fixing Mistakes
```sql
-- Update a set
SELECT update_set('session-id', 'Bench Press', 2, 10, 185);

-- Delete a set
SELECT delete_set('session-id', 'Bench Press', 5);

-- Re-log correct set
SELECT log_set('session-id', 'Bench Press', 3, 8, 185);
```

---

## Migration Files
- Sessions Flat Table: `supabase/migrations/20250108000000_create_sessions_flat_table.sql`
- RPC Functions: `supabase/migrations/20250109000000_create_flat_table_rpc_functions.sql`

## Related Documentation
- [Sessions Flat Table Structure](./sessions_flat_table_structure.md)
- [Workouts Flat Table Structure](./workouts_flat_table_structure.md)
