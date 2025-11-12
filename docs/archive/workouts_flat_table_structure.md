# Workouts Flat Table Structure

## Overview
The `workouts_flat` table denormalizes the JSONB structure from the `workouts` table, creating one row per exercise per day per workout.

## Table Schema

| Column Name | Type | Description |
|-------------|------|-------------|
| `id` | uuid | Primary key |
| `workout_id` | uuid | Foreign key to workouts table |
| `workout_name` | text | Denormalized workout name |
| `workout_description` | text | Denormalized workout description |
| `workout_is_active` | boolean | Denormalized active status |
| `day_name` | text | Day name (e.g., "monday", "tuesday") |
| `exercise_order` | int | Zero-indexed position in day's exercise array |
| `exercise_name` | text | Name of the exercise |
| `sets` | int | Target number of sets |
| `reps` | int | Target number of reps |
| `weight` | int | Target weight |
| `superset_group` | text | Superset grouping (e.g., "A", "B", null) |
| `exercise_notes` | text | Exercise-specific notes |
| `created_at` | timestamp | Row creation timestamp |
| `updated_at` | timestamp | Row update timestamp |

## Example Data

### Original JSONB in workouts table:
```json
{
  "monday": [
    {
      "exercise": "Bench Press",
      "sets": 4,
      "reps": 8,
      "weight": 185,
      "superset_group": null,
      "notes": "Barbell, touch chest each rep"
    },
    {
      "exercise": "Lateral Raises",
      "sets": 3,
      "reps": 12,
      "weight": 25,
      "superset_group": "A",
      "notes": "Dumbbells, control the eccentric"
    }
  ]
}
```

### Flattened rows in workouts_flat table:

| workout_id | workout_name | day_name | exercise_order | exercise_name | sets | reps | weight | superset_group | exercise_notes |
|------------|--------------|----------|----------------|---------------|------|------|--------|----------------|----------------|
| 00000000-... | Push/Pull/Legs v1 | monday | 0 | Bench Press | 4 | 8 | 185 | null | Barbell, touch chest each rep |
| 00000000-... | Push/Pull/Legs v1 | monday | 1 | Lateral Raises | 3 | 12 | 25 | A | Dumbbells, control the eccentric |

## Features

### Automatic Synchronization
- Trigger automatically syncs `workouts_flat` when `workouts` table is modified
- INSERT, UPDATE, and DELETE operations are handled
- DELETE operations cascade automatically via foreign key

### Manual Sync Function
```sql
select sync_workouts_flat();
```
This function completely refreshes the entire flat table from the workouts table.

### Indexes
The table includes indexes for efficient querying:
- `workout_id` - Query all exercises for a workout
- `day_name` - Query all exercises for a specific day across workouts
- `exercise_name` - Query all instances of a specific exercise
- `workout_is_active` - Query active workout exercises
- `(workout_id, day_name)` - Composite index for workout day queries
- `superset_group` - Query superset exercises

## Use Cases

### Query all exercises for a specific day
```sql
SELECT * FROM workouts_flat
WHERE workout_is_active = true
  AND day_name = 'monday'
ORDER BY exercise_order;
```

### Query exercises in a superset
```sql
SELECT * FROM workouts_flat
WHERE workout_id = '...'
  AND day_name = 'monday'
  AND superset_group = 'A'
ORDER BY exercise_order;
```

### Count exercises per day
```sql
SELECT
  workout_name,
  day_name,
  count(*) as exercise_count
FROM workouts_flat
WHERE workout_is_active = true
GROUP BY workout_id, workout_name, day_name
ORDER BY day_name;
```

### Find all workouts containing a specific exercise
```sql
SELECT DISTINCT
  workout_id,
  workout_name,
  day_name
FROM workouts_flat
WHERE exercise_name = 'Bench Press'
ORDER BY workout_name, day_name;
```

## Migration File
Location: `supabase/migrations/20250107000000_create_workouts_flat_table.sql`
