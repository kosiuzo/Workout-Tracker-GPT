# Workout Tracker GPT - Database Documentation

**Last Updated**: 2025-01-16

This document provides a complete reference for the Workout Tracker database schemas and RPC functions. For archived documentation and implementation notes, see `docs/archive/`.

---

## Table of Contents

- [Database Schemas](#database-schemas)
  - [workouts_flat](#workouts_flat)
  - [sessions_flat](#sessions_flat)
  - [exercise_history](#exercise_history)
  - [workout_history](#workout_history)
- [RPC Functions](#rpc-functions)
  - [Aggregation Functions](#aggregation-functions)
  - [Progress & History Functions](#progress--history-functions)
  - [Workout Planning Functions](#workout-planning-functions)
  - [Session Management Functions](#session-management-functions)
  - [Set Logging Functions](#set-logging-functions)
  - [Workout Management Functions](#workout-management-functions)
- [OpenAPI Specification](#openapi-specification)

---

## Database Schemas

### workouts_flat

Denormalized workout table with one row per exercise per day per workout.

**Primary Key**: `(workout_name, day_name, exercise_order)`

| Column | Type | Description |
|--------|------|-------------|
| `workout_name` | text | Name of the workout (allows duplicates) |
| `workout_description` | text | Optional description of workout |
| `workout_is_active` | boolean | Whether this is the active workout |
| `day_name` | text | Day of the week (e.g., "monday") |
| `day_notes` | text | Notes specific to this workout day |
| `exercise_order` | int | Zero-indexed position of exercise in day |
| `exercise_name` | text | Name of the exercise |
| `sets` | int | Planned number of sets |
| `reps` | int | Planned number of reps |
| `weight` | int | Planned weight |
| `superset_group` | text | Superset identifier (e.g., "A", "B") |
| `exercise_notes` | text | Exercise-specific notes |
| `created_at` | timestamptz | Record creation timestamp |
| `updated_at` | timestamptz | Last update timestamp |

**Indexes**:
- `idx_workouts_flat_workout_name` on `workout_name`
- `idx_workouts_flat_day_name` on `day_name`
- `idx_workouts_flat_exercise_name` on `exercise_name`
- `idx_workouts_flat_active` on `workout_is_active` (where true)
- `idx_workouts_flat_workout_day` on `(workout_name, day_name)`
- `idx_workouts_flat_superset` on `(workout_name, day_name, superset_group)`

---

### sessions_flat

Denormalized session table with one row per set per exercise per session.

**Primary Key**: `(workout_name, session_date, exercise_name, set_number)`

| Column | Type | Description |
|--------|------|-------------|
| `workout_name` | text | Name of the workout |
| `session_date` | date | Date of the workout session |
| `session_notes` | text | Session-wide notes |
| `exercise_name` | text | Name of the exercise |
| `set_number` | int | Set number (1, 2, 3, etc.) |
| `reps` | int | Reps performed |
| `weight` | numeric(10,2) | Weight used (supports decimals) |
| `created_at` | timestamptz | Record creation timestamp |
| `updated_at` | timestamptz | Last update timestamp |

**Indexes**:
- `idx_sessions_flat_workout_name` on `workout_name`
- `idx_sessions_flat_date` on `session_date DESC`
- `idx_sessions_flat_exercise_name` on `exercise_name`
- `idx_sessions_flat_workout_date` on `(workout_name, session_date DESC)`
- `idx_sessions_flat_exercise_date` on `(exercise_name, session_date DESC)`

---

### exercise_history

Aggregated exercise statistics by workout, exercise, and date. Computed from `sessions_flat`.

**Primary Key**: `id` (UUID)
**Unique Constraint**: `(workout_name, exercise_name, date)`

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Unique identifier |
| `workout_name` | text | Name of the workout |
| `exercise_name` | text | Name of the exercise |
| `date` | date | Date of the aggregation |
| `total_sets` | int | Total sets performed |
| `total_reps` | int | Total reps performed |
| `total_volume` | numeric | Sum of (weight × reps) |
| `max_weight` | numeric | Maximum weight used |
| `avg_weight` | numeric | Average weight used |
| `created_at` | timestamptz | Record creation timestamp |
| `updated_at` | timestamptz | Last update timestamp |

**Indexes**:
- `idx_exercise_history_workout_date` on `(workout_name, date DESC)`
- `idx_exercise_history_exercise_date` on `(exercise_name, date DESC)`

---

### workout_history

Aggregated workout statistics by workout and date. Computed from `exercise_history`.

**Primary Key**: `id` (UUID)
**Unique Constraint**: `(workout_name, date)`

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Unique identifier |
| `workout_name` | text | Name of the workout |
| `date` | date | Date of the aggregation |
| `total_volume` | numeric | Sum of all exercise volumes |
| `total_sets` | int | Total sets performed |
| `total_reps` | int | Total reps performed |
| `num_exercises` | int | Count of distinct exercises |
| `created_at` | timestamptz | Record creation timestamp |
| `updated_at` | timestamptz | Last update timestamp |

**Indexes**:
- `idx_workout_history_date` on `date DESC`
- `idx_workout_history_workout_date` on `(workout_name, date DESC)`

---

## RPC Functions

**Total**: 27 RPC functions (all tested and working)

### Aggregation Functions

Calculate and populate history tables from session data.

#### `calc_exercise_history(date_override date DEFAULT current_date)`

Aggregates `sessions_flat` data into `exercise_history` for a specific date.

**Returns**: JSON with exercise records created/updated

**Example**:
```sql
SELECT calc_exercise_history('2025-01-15');
```

---

#### `calc_workout_history(date_override date DEFAULT current_date)`

Rolls up `exercise_history` into `workout_history` for a specific date.

**Returns**: JSON with workout records created/updated

**Note**: Must be run after `calc_exercise_history`

---

#### `calc_all_history(date_override date DEFAULT current_date)`

Orchestrates both `calc_exercise_history` and `calc_workout_history` in sequence.

**Returns**: JSON with combined results from both functions

---

### Progress & History Functions

Retrieve historical workout and exercise data.

#### `get_recent_progress(days_back int DEFAULT 7, workout_name_param text DEFAULT NULL)`

Returns workout history for the last N days, optionally filtered by workout name.

**Returns**: JSON array of workout history records with volume/sets/reps stats

---

#### `get_exercise_progress(exercise_name_param text, days_back int DEFAULT 30, workout_name_param text DEFAULT NULL)`

Returns aggregated history for a specific exercise over time.

**Returns**: JSON array of exercise history with stats

---

#### `get_exercise_history_flat(exercise_name_param text, days_back int DEFAULT 30, workout_name_param text DEFAULT NULL)`

Returns detailed set-by-set history for a specific exercise from `sessions_flat`.

**Returns**: JSON with detailed per-set data and summary statistics

---

### Workout Planning Functions

Manage and query workout plans.

#### `get_active_workout()`

Returns the currently active workout with all details.

**Returns**: JSON with full workout structure including days and exercises

---

#### `get_todays_exercises_flat()`

Returns today's workout exercises from the active workout using `workouts_flat`.

**Returns**: JSON with exercises for the current day of the week

**Example Response**:
```json
{
  "success": true,
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
      "notes": "Barbell"
    }
  ]
}
```

---

#### `get_exercises_for_day_flat(day_name_param text, workout_name_param text DEFAULT NULL)`

Returns exercises for a specific day from `workouts_flat`.

**Parameters**:
- `day_name_param`: Day of the week (e.g., "monday")
- `workout_name_param`: Optional workout name (uses active workout if null)

**Returns**: JSON with structured exercise data for the specified day

---

#### `get_workout_for_day(day_name text, workout_uuid uuid DEFAULT NULL)`

Legacy function that returns workout plan for a specific day.

**Returns**: JSON with JSONB days data

---

#### `set_active_workout(workout_name_param text)`

Activates a workout plan by name and deactivates all others.

**Parameters**:
- `workout_name_param`: Name of workout to activate

**Returns**: JSON with success status

---

### Session Management Functions

Manage and query workout sessions.

#### `get_todays_session()`

Returns today's workout session with all logged sets from the active workout.

**Returns**: JSON with session data or error if no session exists

---

#### `get_session_sets_flat(workout_name_param text, session_date_param date)`

Returns all sets for a specific session from `sessions_flat`.

**Returns**: JSON array with all sets including exercise/set/reps/weight data

---

#### `get_workout_summary_flat(workout_name_param text, session_date_param date)`

Returns summary statistics for a workout session grouped by exercise.

**Returns**: JSON with aggregated stats (total sets/reps/volume per exercise)

---

### Set Logging Functions

Log and modify workout sets.

#### `log_set(workout_name_param text, session_date_param date, exercise_name_param text, set_number_param int, reps_param int, weight_param numeric, session_notes_param text DEFAULT NULL)`

Logs a single set to `sessions_flat`. Creates or updates the set.

**Returns**: JSON with logged set data

**Example**:
```sql
SELECT log_set('PPL v1', '2025-01-16', 'Bench Press', 1, 10, 185);
```

---

#### `log_multiple_sets(workout_name_param text, session_date_param date, sets_data jsonb, session_notes_param text DEFAULT NULL)`

Logs multiple sets at once from a JSON array.

**Parameters**:
- `sets_data`: JSON array of sets with `exercise_name`, `set_number`, `reps`, `weight`

**Example**:
```sql
SELECT log_multiple_sets('PPL v1', '2025-01-16', '[
  {"exercise_name": "Bench Press", "set_number": 1, "reps": 10, "weight": 185},
  {"exercise_name": "Bench Press", "set_number": 2, "reps": 9, "weight": 185}
]'::jsonb);
```

---

#### `log_workout_day(sets_data jsonb, day_name_param text DEFAULT NULL, workout_name_param text DEFAULT NULL, session_date_param date DEFAULT current_date, session_notes_param text DEFAULT NULL)`

**NEW** - Logs all sets for a workout day in a single call with smart defaults.

**Smart Defaults**:
- `workout_name_param`: Defaults to active workout if not specified
- `day_name_param`: Defaults to current day of week if not specified
- `session_date_param`: Defaults to today

**Parameters**:
- `sets_data`: JSON array of sets with `exercise_name`, `set_number`, `reps`, `weight`
- `day_name_param`: Optional day name (e.g., "monday")
- `workout_name_param`: Optional workout name
- `session_date_param`: Optional session date
- `session_notes_param`: Optional session notes

**Returns**: JSON with workout_name, day_name, session_date, rows_inserted, rows_updated

**Example 1** - Log today's workout (uses active workout and current day):
```sql
SELECT log_workout_day('[
  {"exercise_name": "Bench Press", "set_number": 1, "reps": 10, "weight": 185},
  {"exercise_name": "Bench Press", "set_number": 2, "reps": 9, "weight": 185},
  {"exercise_name": "Incline Press", "set_number": 1, "reps": 12, "weight": 135}
]'::jsonb);
```

**Example 2** - Log specific day and workout:
```sql
SELECT log_workout_day(
  '[{"exercise_name": "Deadlift", "set_number": 1, "reps": 5, "weight": 315}]'::jsonb,
  'friday',
  'PPL v1',
  '2025-01-17',
  'Felt strong today'
);
```

---

#### `update_set(workout_name_param text, session_date_param date, exercise_name_param text, set_number_param int, reps_param int DEFAULT NULL, weight_param numeric DEFAULT NULL)`

Updates reps and/or weight for a specific logged set.

**Returns**: JSON with updated set data

---

#### `delete_set(workout_name_param text, session_date_param date, exercise_name_param text, set_number_param int)`

Deletes a specific set from a session.

**Returns**: JSON with success status

---

#### `update_session_notes(workout_name_param text, session_date_param date, session_notes_param text)`

Updates session notes for a workout on a specific date.

**Returns**: JSON with number of rows updated

---

### Workout Management Functions

Create and modify workout plans.

#### `create_workout_from_json(workout_json jsonb)`

Creates a complete workout from JSON structure. Populates `workouts_flat` table.

**Allows duplicate workout names** - uniqueness is enforced by composite key `(workout_name, day_name, exercise_order)`.

**Parameters**:
- `workout_json`: JSON object with `workout_name`, `workout_description`, `is_active`, and `days` array

**Example JSON**:
```json
{
  "workout_name": "Push/Pull/Legs v1",
  "workout_description": "Classic PPL split",
  "is_active": true,
  "days": [
    {
      "day_name": "monday",
      "day_notes": "Push day - focus on form",
      "exercises": [
        {
          "exercise_name": "Bench Press",
          "sets": 4,
          "reps": 8,
          "weight": 185,
          "superset_group": null,
          "exercise_notes": "Barbell"
        }
      ]
    }
  ]
}
```

**Returns**: JSON with success status and rows inserted

---

#### `add_exercise_to_day(workout_uuid uuid, day_name text, exercise_name text, sets int, reps int, weight int, superset_group text, notes text)`

Adds an exercise to a specific day in a workout.

**Returns**: JSON with success/error status

---

#### `remove_exercise_from_day(workout_uuid uuid, day_name text, exercise_name text)`

Removes an exercise from a specific day.

**Returns**: JSON with success/error status

---

#### Additional Workout Update Functions

- `update_workout_day_weight(workout_uuid, day_name, exercise_name, new_weight)` - Updates planned weight
- `update_entry_reps(session_uuid, exercise_name, set_number, new_reps)` - Updates logged reps
- `update_entry_weight(session_uuid, exercise_name, set_number, new_weight)` - Updates logged weight
- `get_todays_workout()` - Returns today's workout details

---

## OpenAPI Specification

The ChatGPT-optimized OpenAPI v2 specification is available at:

**`openapi-gpt-optimized-v2.yaml`**

This specification includes all active endpoints for integration with ChatGPT and other API consumers.

For older API specifications and implementation notes, see `docs/archive/openapi/`.

---

## Architecture Notes

- All RPC functions use PostgreSQL `security definer` for consistent permissions
- All functions return JSON for API compatibility
- History tables use `workout_name` (text) as the correlation key
- Session data stored in `sessions_flat` with denormalized structure
- Workout plans stored in `workouts_flat` with denormalized structure
- Aggregation functions are idempotent (safe to run multiple times)
- Timestamps automatically maintained by triggers
- **Duplicate workout names are allowed** - uniqueness enforced by composite keys

---

## Archive

Historical documentation, implementation notes, and migration guides are available in:

**`docs/archive/`**

This includes:
- Architecture and setup guides
- Implementation summaries
- Migration strategies and execution guides
- Session summaries and task completion logs
- OpenAPI file progression and validation reports
- Claude session documentation
