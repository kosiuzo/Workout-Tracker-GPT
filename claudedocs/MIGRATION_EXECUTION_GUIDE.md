# Migration Execution Guide: JSON to Flat Tables

## Overview
This guide provides step-by-step instructions for migrating your workout database from JSON-based tables to the new flat table structure.

## Pre-Migration Checklist

- [ ] Back up your database
- [ ] Review the `MIGRATION_STRATEGY.md` document
- [ ] Ensure no active queries or connections to the tables being migrated
- [ ] Verify you have admin access to Supabase

## Migration Execution Order

### Step 1: Create Flat Table Structure (20250107000000_create_workouts_flat_table.sql)
**Status**: ✅ Ready to apply

This migration creates the new `workouts_flat` table with:
- Composite primary key: `(workout_name, day_name, exercise_order)`
- Columns: workout_name, description, is_active, day_name, day_notes, exercise details, timestamps
- Indexes for efficient querying by workout name, day, exercise, and supersets
- RLS policies for single-user mode

**Apply with**:
```sql
-- In Supabase SQL Editor
\i supabase/migrations/20250107000000_create_workouts_flat_table.sql
```

Expected output:
```
CREATE TABLE
CREATE INDEX (x5)
COMMENT
```

### Step 2: Create Sessions Flat Table (20250108000000_create_sessions_flat_table.sql)
**Status**: ✅ Ready to apply (optional - already exists)

Creates `sessions_flat` for denormalized session data.

### Step 3: Migrate Data from Workouts (20250110000000_migrate_workouts_to_flat.sql)
**Status**: ✅ Ready to apply

Executes the data migration:

**What it does**:
1. Reads all workout data from the JSON `workouts.days` column
2. Extracts `day_notes` for each day
3. Flattens exercise arrays into individual rows
4. Inserts into `workouts_flat` with full metadata

**Apply with**:
```sql
-- In Supabase SQL Editor
\i supabase/migrations/20250110000000_migrate_workouts_to_flat.sql
```

**Verification output**:
The migration includes SQL checks that show:
- Number of workouts migrated
- Total exercises migrated
- Total days covered
- **IMPORTANT**: Exercise count comparison (source vs flat table)

**What to verify**:
```
Workouts migrated: X
Total exercises: Y
Days covered: Z
```

All counts should match your expectations. If there are mismatches, **STOP** and investigate before proceeding.

### Step 4: Drop Old Tables (20250111000000_drop_old_workouts_table.sql)
**Status**: ⚠️ Use ONLY after Step 3 verification

This migration is **irreversible**. Only run after confirming Step 3 was successful.

**What it does**:
1. Drops triggers and sync functions
2. Drops dependent tables: `sessions`, `exercise_history`, `workout_history`, `workouts`
3. Verifies all old tables are removed

**Apply with**:
```sql
-- In Supabase SQL Editor
\i supabase/migrations/20250111000000_drop_old_workouts_table.sql
```

**Expected output**:
```
workouts         | DROPPED
sessions         | DROPPED
exercise_history | DROPPED
workout_history  | DROPPED
workouts_flat    | EXISTS
```

## Important Notes

### Before Running Migrations:
1. **Test in development first** - These migrations are irreversible
2. **Ensure your JSON structure matches expectations**:
   ```json
   {
     "monday": {
       "day_notes": "Optional notes about this day",
       "exercises": [
         {
           "exercise": "Exercise Name",
           "sets": 3,
           "reps": 10,
           "weight": 185,
           "notes": "Optional exercise notes",
           "superset_group": null
         }
       ]
     }
   }
   ```
3. **No active connections** - Close any open database connections

### If Migration Fails:
1. Check error messages carefully
2. Verify your JSON structure matches expectations
3. Restore from backup if needed
4. Contact support or review the error with the migration script

### Application Code Updates Needed After Migration:
1. Update all API endpoints that query `workouts` to use `workouts_flat`
2. Replace JSONB extraction logic with direct column references
3. Update UI queries to reference flat table structure
4. Remove any code that depends on `sessions`, `exercise_history`, or `workout_history`

## Rollback Plan

If something goes wrong **before Step 4**:
1. Delete records from `workouts_flat` using migration ID
2. Run Supabase migration rollback
3. Verify original tables are intact

If something goes wrong **after Step 4**:
1. Restore from database backup
2. Retry the entire process

## Expected Data Structure After Migration

### workouts_flat table:
Each row represents one exercise in one day of a workout.

```
workout_name | workout_description | day_name | day_notes | exercise_name | sets | reps | weight | exercise_notes | superset_group | ...
"Push Day"   | "Chest & Tri"       | "Monday" | "Strong!" | "Bench Press" | 3    | 10   | 185    | "Heavy today"  | null           | ...
"Push Day"   | "Chest & Tri"       | "Monday" | "Strong!" | "Tricep Dips" | 3    | 8    | 45     | null           | "A"            | ...
```

## Verification Queries After Migration

```sql
-- Check total rows
select count(*) from workouts_flat;

-- Check workouts
select distinct workout_name from workouts_flat;

-- Check days per workout
select workout_name, count(distinct day_name)
from workouts_flat
group by workout_name;

-- Check day notes are populated
select distinct day_name, day_notes
from workouts_flat
where day_notes is not null;
```

## Success Criteria

✅ Migration is successful when:
1. All data is migrated (verified by row counts)
2. Exercise counts match source table
3. `day_notes` is properly extracted
4. All old tables are dropped (Step 4 only)
5. Application code works with new flat tables
6. Queries are faster due to direct column access

## Next Steps

After successful migration:
1. Update application code to use `workouts_flat` exclusively
2. Remove any JSONB parsing logic from your application
3. Update API documentation
4. Test all endpoints with new data structure
5. Monitor performance improvements
