# Workout Tracker GPT - Database Schema

## Workouts Table

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid | Primary key |
| `workout_name` | text | Workout name (allows duplicates) |
| `workout_description` | text | Workout description |
| `workout_is_active` | boolean | Currently active workout |
| `day_name` | text | Day name (e.g., "monday", "tuesday") |
| `day_notes` | text | Notes for this workout day |
| `exercise_order` | float | Exercise position in day (allows 1.5 between 1 and 2) |
| `exercise_name` | text | Exercise name |
| `sets` | int | Target number of sets |
| `reps` | int | Target number of reps |
| `weight` | int | Target weight |
| `superset_group` | text | Superset grouping (e.g., "A", "B", null) |
| `exercise_notes` | text | Exercise-specific notes |
| `created_at` | timestamp | Row creation time |
| `updated_at` | timestamp | Row update time |

## Sessions Table

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid | Primary key |
| `workout_name` | text | Workout name |
| `session_date` | date | Session date |
| `session_notes` | text | Session notes |
| `exercise_name` | text | Exercise name |
| `sets` | int | Number of sets performed (e.g., 3) |
| `reps` | int | Reps per set (e.g., 10) |
| `weight` | numeric(10,2) | Weight used |
| `created_at` | timestamp | Row creation time |
| `updated_at` | timestamp | Row update time |

**Note**: One row represents "X sets of Y reps at Z weight" (e.g., one row = "3 sets of 10 reps at 185 lbs"). Multiple rows for the same exercise on the same date with different set/rep/weight combinations are allowed for flexibility.

## Exercise History Table

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid | Primary key |
| `workout_name` | text | Workout name |
| `exercise_name` | text | Exercise name |
| `date` | date | Session date |
| `total_sets` | int | Total sets performed |
| `total_reps` | int | Total reps performed |
| `total_volume` | numeric | Total weight × reps |
| `max_weight` | numeric | Heaviest weight used |
| `avg_weight` | numeric | Average weight |
| `created_at` | timestamp | Row creation time |
| `updated_at` | timestamp | Row update time |

## Workout History Table

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid | Primary key |
| `workout_name` | text | Workout name |
| `date` | date | Session date |
| `total_volume` | numeric | Total volume across all exercises |
| `total_sets` | int | Total sets performed |
| `total_reps` | int | Total reps performed |
| `num_exercises` | int | Number of unique exercises |
| `created_at` | timestamp | Row creation time |
| `updated_at` | timestamp | Row update time |

---

## RPC Functions

### 1. create_workout
Creates a new workout with name and description. Fails if the workout name already exists (prevents duplicates).

**Signature:**
```sql
create_workout(p_workout_name text, p_workout_description text) → jsonb
```

**Parameters:**
- `p_workout_name` (text): Unique name for the workout (e.g., "Push/Pull/Legs v1")
- `p_workout_description` (text): Description of the workout (e.g., "Classic PPL split focusing on progressive overload")

**Returns:** JSON object with success status and details
```json
{
  "success": true,
  "message": "Workout created successfully",
  "workout_name": "Push/Pull/Legs v1",
  "workout_description": "Classic PPL split focusing on progressive overload"
}
```

**Error Handling:**
- Raises exception if workout name already exists

**Example:**
```sql
select create_workout(
  'Push/Pull/Legs v1',
  'Classic PPL split focusing on progressive overload'
);
```

---

### 2. add_workout_day
Appends exercises for a specific day to an existing workout. Call this function once per day to build a multi-day workout while avoiding payload limits.

**Signature:**
```sql
add_workout_day(
  p_workout_name text,
  p_day_name text,
  p_exercises jsonb
) → jsonb
```

**Parameters:**
- `p_workout_name` (text): Name of the workout to append to
- `p_day_name` (text): Day name in lowercase (e.g., "monday", "tuesday", "wednesday")
- `p_exercises` (jsonb): JSON array of exercise objects

**Exercise Object Structure:**
```json
{
  "exercise_name": "Bench Press",
  "sets": 4,
  "reps": 8,
  "weight": 185,
  "exercise_order": 1,
  "superset_group": null,
  "exercise_notes": "Barbell, touch chest each rep"
}
```

**Returns:** JSON object with success status and exercise count
```json
{
  "success": true,
  "message": "Exercises added successfully",
  "workout_name": "Push/Pull/Legs v1",
  "day_name": "monday",
  "exercises_added": 2
}
```

**Error Handling:**
- Raises exception if workout does not exist

**Example:**
```sql
select add_workout_day(
  'Push/Pull/Legs v1',
  'monday',
  '[
    {"exercise_name": "Bench Press", "sets": 4, "reps": 8, "weight": 185, "exercise_order": 1, "superset_group": null, "exercise_notes": "Barbell"},
    {"exercise_name": "Incline Press", "sets": 3, "reps": 10, "weight": 140, "exercise_order": 2, "superset_group": null, "exercise_notes": "Dumbbells"}
  ]'::jsonb
);
```

---

### 3. set_active_workout
Sets the specified workout as the active workout. Automatically deactivates all other workouts.

**Signature:**
```sql
set_active_workout(p_workout_name text) → jsonb
```

**Parameters:**
- `p_workout_name` (text): Name of the workout to activate

**Returns:** JSON object with success status
```json
{
  "success": true,
  "message": "Workout activated successfully",
  "workout_name": "Push/Pull/Legs v1",
  "is_active": true
}
```

**Error Handling:**
- Raises exception if workout does not exist

**Example:**
```sql
select set_active_workout('Push/Pull/Legs v1');
```

---

### 4. get_active_workout
Retrieves the currently active workout grouped by day, excluding internal placeholder rows.

**Signature:**
```sql
get_active_workout() → jsonb
```

**Parameters:** None

**Returns:** JSON object with workout details and exercises grouped by day
```json
{
  "workout_name": "Push/Pull/Legs v1",
  "workout_description": "Classic PPL split focusing on progressive overload",
  "days": {
    "monday": [
      {
        "exercise_name": "Bench Press",
        "sets": 4,
        "reps": 8,
        "weight": 185,
        "exercise_order": 1,
        "superset_group": null,
        "exercise_notes": "Barbell, touch chest each rep"
      },
      {
        "exercise_name": "Incline Press",
        "sets": 3,
        "reps": 10,
        "weight": 140,
        "exercise_order": 2,
        "superset_group": null,
        "exercise_notes": "Dumbbells"
      }
    ],
    "tuesday": [...]
  }
}
```

**Error Handling:**
- Raises exception if no active workout exists

**Example:**
```sql
select get_active_workout();
```

---

### 5. log_current_workout
Logs the active workout for a specified day into the sessions table. Copies sets, reps, and weight from the workout template.

**Signature:**
```sql
log_current_workout(
  p_day_name text DEFAULT NULL,
  p_session_date date DEFAULT CURRENT_DATE
) → jsonb
```

**Parameters:**
- `p_day_name` (text, optional): Day name in lowercase (e.g., "monday"). If NULL, uses the current day of the week
- `p_session_date` (date, optional): Session date. Defaults to today

**Returns:** JSON object with success status and exercise count logged
```json
{
  "success": true,
  "message": "Workout logged successfully",
  "workout_name": "Push/Pull/Legs v1",
  "session_date": "2025-01-25",
  "day_name": "monday",
  "exercises_logged": 2
}
```

**Error Handling:**
- Raises exception if no active workout exists
- Raises exception if no exercises found for the specified day

**Examples:**
```sql
-- Log today's workout using current day of week
select log_current_workout();

-- Log a specific day with explicit date
select log_current_workout('monday', '2025-01-25'::date);

-- Log a past workout for a specific date
select log_current_workout('friday', '2025-01-24'::date);
```

---

## Workflow Example

```sql
-- 1. Create a new workout
select create_workout(
  'Push/Pull/Legs v1',
  'Classic PPL split focusing on progressive overload'
);

-- 2. Add exercises for Monday (push day)
select add_workout_day(
  'Push/Pull/Legs v1',
  'monday',
  '[
    {"exercise_name": "Bench Press", "sets": 4, "reps": 8, "weight": 185, "exercise_order": 1, "superset_group": null, "exercise_notes": "Barbell"},
    {"exercise_name": "Incline Press", "sets": 3, "reps": 10, "weight": 140, "exercise_order": 2, "superset_group": null, "exercise_notes": "Dumbbells"}
  ]'::jsonb
);

-- 3. Add exercises for Tuesday (pull day)
select add_workout_day(
  'Push/Pull/Legs v1',
  'tuesday',
  '[
    {"exercise_name": "Deadlift", "sets": 4, "reps": 6, "weight": 275, "exercise_order": 1, "superset_group": null, "exercise_notes": "Conventional"},
    {"exercise_name": "Pull-ups", "sets": 4, "reps": 8, "weight": 0, "exercise_order": 2, "superset_group": null, "exercise_notes": "Bodyweight"}
  ]'::jsonb
);

-- 4. Set as active
select set_active_workout('Push/Pull/Legs v1');

-- 5. Get active workout to view
select get_active_workout();

-- 6. Log today's workout
select log_current_workout();

-- 7. Log a specific past workout
select log_current_workout('friday', '2025-01-24'::date);
```

---

## Key Design Notes

### Workout Creation
- Workouts are created with metadata (name, description) and then populated with exercise data
- Placeholder rows are created internally to track the workout metadata
- Placeholder rows are automatically filtered out from results

### Sessions vs Workouts
- **Workouts Table**: Template/plan for exercises with target sets, reps, and weight
- **Sessions Table**: Actual logged workouts with actual sets, reps, and weight performed
- One session row represents "X sets of Y reps at Z weight" (e.g., "3 sets of 10 reps at 185 lbs")
- Multiple session rows allowed for same exercise on same date (different set/rep/weight combinations)

### Duplicate Prevention
- Workout names must be unique
- `create_workout` will fail if the name already exists
- Plan versions as part of the name (e.g., "PPL v1", "PPL v2")

### Payload Optimization
- `add_workout_day` accepts one day's exercises per call to avoid payload limits
- Build multi-day workouts incrementally (one call per day)
