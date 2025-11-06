# Sessions Flat Table Structure

## Overview
The `sessions_flat` table denormalizes the JSONB structure from the `sessions` table, creating one row per set per exercise per session.

## Table Schema

| Column Name | Type | Description |
|-------------|------|-------------|
| `id` | uuid | Primary key |
| `session_id` | uuid | Foreign key to sessions table |
| `workout_id` | uuid | Foreign key to workouts table (denormalized) |
| `session_date` | date | Session date (denormalized) |
| `session_notes` | text | Session notes (denormalized) |
| `exercise_name` | text | Name of the exercise |
| `set_number` | int | Set number (1, 2, 3, etc.) |
| `reps` | int | Number of reps performed |
| `weight` | numeric(10,2) | Weight used (supports decimals) |
| `created_at` | timestamp | Row creation timestamp |
| `updated_at` | timestamp | Row update timestamp |

## Example Data

### Original JSONB in sessions table:
```json
{
  "entries": [
    {
      "exercise": "Bench Press",
      "set": 1,
      "reps": 10,
      "weight": 185
    },
    {
      "exercise": "Bench Press",
      "set": 2,
      "reps": 9,
      "weight": 185
    },
    {
      "exercise": "Incline Dumbbell Press",
      "set": 1,
      "reps": 10,
      "weight": 60
    }
  ]
}
```

### Flattened rows in sessions_flat table:

| session_id | exercise_name | set_number | reps | weight | session_date |
|------------|---------------|------------|------|--------|--------------|
| abc123... | Bench Press | 1 | 10 | 185 | 2025-01-06 |
| abc123... | Bench Press | 2 | 9 | 185 | 2025-01-06 |
| abc123... | Incline Dumbbell Press | 1 | 10 | 60 | 2025-01-06 |

## Features

### Automatic Synchronization
- Trigger automatically syncs `sessions_flat` when `sessions` table is modified
- INSERT, UPDATE, and DELETE operations are handled
- DELETE operations cascade automatically via foreign key

### Manual Sync Function
```sql
select sync_sessions_flat();
```
This function completely refreshes the entire flat table from the sessions table.

### Indexes
The table includes indexes for efficient querying:
- `session_id` - Query all sets for a session
- `workout_id` - Query all sets for a workout
- `session_date` - Query sets by date
- `exercise_name` - Query all instances of a specific exercise
- `(workout_id, session_date)` - Composite index for workout date queries
- `(exercise_name, session_date)` - Composite index for exercise progression
- `(session_id, exercise_name, set_number)` - Composite index for grouping sets

## Use Cases

### Query all sets for a session
```sql
SELECT * FROM sessions_flat
WHERE session_id = '...'
ORDER BY exercise_name, set_number;
```

### Get exercise progression over time
```sql
SELECT
  session_date,
  set_number,
  reps,
  weight,
  reps * weight as volume
FROM sessions_flat
WHERE exercise_name = 'Bench Press'
ORDER BY session_date DESC, set_number;
```

### Calculate daily volume for an exercise
```sql
SELECT
  session_date,
  count(*) as total_sets,
  sum(reps) as total_reps,
  sum(reps * weight) as total_volume,
  max(weight) as max_weight
FROM sessions_flat
WHERE exercise_name = 'Squat'
GROUP BY session_date
ORDER BY session_date DESC;
```

### Find personal records
```sql
SELECT
  exercise_name,
  max(weight) as max_weight,
  max(reps * weight) as max_volume_per_set
FROM sessions_flat
GROUP BY exercise_name
ORDER BY exercise_name;
```

## Migration File
Location: `supabase/migrations/20250108000000_create_sessions_flat_table.sql`
