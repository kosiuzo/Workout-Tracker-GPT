# Migration Strategy: JSON Tables to Flat Tables

## Overview
This document outlines the strategy for migrating from the JSON-based `workouts` and `sessions` tables to the normalized `workouts_flat` and `sessions_flat` tables.

## Key Changes

### 1. workouts_flat Table
**New Features:**
- ✅ `day_notes` column added - allows notes specific to each workout day
- ✅ Removed redundant `id` and `workout_id` columns
- ✅ Composite primary key: `(workout_name, day_name, exercise_order)` ensures unique exercises per day
- ✅ Independent structure - can exist without the `workouts` table

**Schema Changes:**
```sql
-- OLD: id uuid PRIMARY KEY, workout_id uuid REFERENCES workouts(id)
-- NEW: PRIMARY KEY (workout_name, day_name, exercise_order)
-- NEW: day_notes text
```

**Why This Design:**
- No redundant UUIDs - the natural key is more efficient
- Workout name uniqueness enforced at the table level
- Indexes use `workout_name` instead of `workout_id` for faster queries

### 2. sessions_flat Table
**Current State:**
- Already has one row per set per exercise per session
- Independent structure with no foreign key to sessions table

## Migration Path

### Phase 1: Data Structure Preparation ✅
- `workouts_flat` schema created with:
  - `day_notes` column for day-specific notes
  - Composite primary key: `(workout_name, day_name, exercise_order)`
  - No redundant UUID fields
  - No foreign key to original `workouts` table
  - RLS policies enabled

### Phase 2: Data Migration (20250110000000_migrate_workouts_to_flat.sql)
Migrates all workout data from JSON to flat structure:

1. **Extract from JSONB structure**
   - Reads `workouts.days` column (contains day objects with exercises array)
   - Extracts `day_notes` from each day object
   - Flattens `exercises` array into individual rows
   - Preserves all exercise metadata and timestamps

2. **Insert into workouts_flat**
   - One row per exercise per day per workout
   - Includes all denormalized data for fast queries
   - Uses `on conflict do nothing` to handle duplicates safely

3. **Verify Migration**
   - Provides execution summary (workouts, exercises, days counts)
   - Compares source vs flat table exercise counts
   - Flags any mismatches for investigation

### Phase 3: Drop Original Tables (20250111000000_drop_old_workouts_table.sql)
ONLY run after Phase 2 is verified successful:

1. **Remove triggers and functions**
   - Drop sync/trigger functions (no longer needed)
   - Drop update timestamp triggers

2. **Drop dependent tables**
   - `sessions` → migrate to `sessions_flat` first
   - `exercise_history` → deprecated, use flat tables
   - `workout_history` → deprecated, use flat tables

3. **Drop main table**
   - Drop `workouts` table (the old JSON structure)

4. **Verify cleanup**
   - Confirm all old tables are gone
   - Confirm `workouts_flat` still exists

## Expected JSON Structure After Migration

### Workouts Days Structure:
```json
{
  "monday": {
    "day_notes": "Chest and triceps - felt strong today",
    "exercises": [
      {
        "exercise": "Bench Press",
        "sets": 3,
        "reps": 10,
        "weight": 185,
        "notes": "Last set was tough",
        "superset_group": null
      },
      {
        "exercise": "Tricep Dips",
        "sets": 3,
        "reps": 8,
        "weight": 45,
        "notes": null,
        "superset_group": "A"
      }
    ]
  },
  "wednesday": {
    "day_notes": "Back day - working on pull-ups",
    "exercises": [...]
  }
}
```

## Benefits of Flat Table Structure

1. **Structured Data** - No more nested JSON parsing
2. **ChatGPT-Friendly** - Easier to query and understand exercise-by-exercise data
3. **Better Indexing** - Direct column indexing on day_notes, exercise_name, etc.
4. **Cleaner Updates** - Update individual exercises without modifying entire JSONB objects
5. **Day-Level Notes** - New ability to track daily notes separate from exercise notes

## Important Notes

### For ChatGPT Integration
- `workouts_flat` provides exercise-level data
- `sessions_flat` provides actual performance data
- `day_notes` allows contextual information about workout days
- Easier to build dynamic UI components based on flat table structure

### Database Queries
- Replace JSONB extraction queries with simple column references
- No more `jsonb_array_elements()` or `->>'field'` operators
- Direct SQL joins and aggregations possible

### Application Updates Needed
- Update any API endpoints that read from `workouts` to use `workouts_flat`
- Update any API endpoints that read from `sessions` to use `sessions_flat`
- Update UI queries to reference new column names

## Next Steps

1. Create migration script in `20250111000000_migrate_data_to_flat_tables.sql`
2. Run migration to populate flat tables with existing data
3. Validate data integrity
4. Update application code to use flat tables
5. Test all endpoints with new structure
