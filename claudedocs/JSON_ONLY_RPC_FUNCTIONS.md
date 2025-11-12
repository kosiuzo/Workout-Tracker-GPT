# RPC Functions - JSON-Only Dependencies Analysis

## Summary
The following RPC functions **ONLY work with the JSON-based table structure** and reference the old `workouts` and `sessions` tables that contain JSONB columns. These functions cannot operate with the new flat table architecture (`workouts_flat`, `sessions_flat`).

---

## JSON-ONLY Functions (12 total)

### 1. **Workout Manipulation Functions** (6 functions)
These functions manipulate the JSONB `days` column structure in the `workouts` table:

#### ✅ `add_exercise_to_day(workout_uuid, day_name, exercise_name, ...)`
- **Location**: `20250103000000_create_json_manipulation_functions.sql`
- **Dependencies**:
  - Reads from `workouts.id` (UUID)
  - Reads/writes `workouts.days` (JSONB structure)
- **What it does**: Appends a new exercise object to the JSONB array for a specific day
- **Why it's JSON-only**: Directly manipulates JSONB `days` column using `jsonb_set()` and `||` operators
- **Migration needed**: Refactor to insert into `workouts_flat` instead

#### ✅ `remove_exercise_from_day(workout_uuid, day_name, exercise_name)`
- **Location**: `20250103000000_create_json_manipulation_functions.sql`
- **Dependencies**:
  - Reads from `workouts.id` (UUID)
  - Reads/writes `workouts.days` (JSONB structure)
- **What it does**: Removes an exercise from the JSONB array for a specific day
- **Why it's JSON-only**: Directly filters/removes from JSONB `days` column array
- **Migration needed**: Refactor to delete from `workouts_flat` instead

#### ✅ `update_workout_day_weight(workout_uuid, day_name, exercise_position, weight)`
- **Location**: `20250103000000_create_json_manipulation_functions.sql`
- **Dependencies**:
  - Reads from `workouts.id` (UUID)
  - Reads/writes `workouts.days` (JSONB structure)
- **What it does**: Updates the weight field of a specific exercise in a day
- **Why it's JSON-only**: Uses `jsonb_set()` to update nested JSONB fields
- **Migration needed**: Refactor to update `workouts_flat` records instead

#### ✅ `create_workout(name, description, is_active)`
- **Location**: `20250105000000_update_create_workout_require_days.sql`
- **Dependencies**:
  - Writes to `workouts.name`, `workouts.description`, `workouts.is_active`, `workouts.days` (JSONB)
- **What it does**: Creates a new workout with empty JSONB `days` structure
- **Why it's JSON-only**: Explicitly creates `days` as empty JSONB object `'{}'::jsonb`
- **Migration needed**: Refactor to only insert into `workouts_flat` (no days/exercises yet)

#### ✅ `get_active_workout()`
- **Location**: `20250106000000_update_get_active_workout_with_current_day.sql`
- **Dependencies**:
  - Reads from `workouts.id`, `workouts.name`, `workouts.days` (JSONB)
  - Uses JSONB manipulation to extract current day exercises
- **What it does**: Returns active workout with today's exercises extracted from JSONB
- **Why it's JSON-only**: Directly reads and processes `workouts.days` JSONB structure
- **Migration needed**: Refactor to read from `workouts_flat` instead

#### ✅ `get_workout_for_day(workout_uuid, day_name)`
- **Location**: `20250102000000_create_rpc_functions.sql`
- **Dependencies**:
  - Reads from `workouts.id`, `workouts.name`
  - Reads `workouts.days` (JSONB) and extracts specific day
- **What it does**: Returns all exercises for a workout on a specific day
- **Why it's JSON-only**: Uses `days->day_name` to access JSONB nested structure
- **Migration needed**: Query from `workouts_flat` filtered by day_name instead

---

### 2. **Session History Functions** (2 functions)
These functions manipulate the JSONB `entries` column in the `sessions` table:

#### ✅ `update_entry_weight(session_uuid, entry_index, weight)`
- **Location**: `20250103000000_create_json_manipulation_functions.sql`
- **Dependencies**:
  - Reads from `sessions.id` (UUID)
  - Reads/writes `sessions.entries` (JSONB array)
- **What it does**: Updates the weight field of a specific set entry in a session
- **Why it's JSON-only**: Uses `jsonb_set()` to update JSONB array element at specific index
- **Migration needed**: Refactor to update `sessions_flat` records instead

#### ✅ `update_entry_reps(session_uuid, entry_index, reps)`
- **Location**: `20250103000000_create_json_manipulation_functions.sql`
- **Dependencies**:
  - Reads from `sessions.id` (UUID)
  - Reads/writes `sessions.entries` (JSONB array)
- **What it does**: Updates the reps field of a specific set entry in a session
- **Why it's JSON-only**: Uses `jsonb_set()` to update JSONB array element
- **Migration needed**: Refactor to update `sessions_flat` records instead

---

### 3. **Aggregation Functions** (1 function - MIXED)

#### ⚠️ `calc_exercise_history(date_override)` - **MIXED/TRANSITIONAL**
- **Location**: `20250102000000_create_rpc_functions.sql`
- **Dependencies**:
  - Reads from `sessions_flat` (NEW)
  - Reads from `workouts_flat` (NEW)
  - Reads from `workouts` (OLD - UUID lookup only)
  - Writes to `exercise_history` (needs schema update)
- **Status**: PARTIALLY CONVERTED but still references old `workouts` table
- **Note**: Updated version exists in `20250121000000_update_rpc_functions_for_flat_tables.sql` that uses `workout_name` instead of UUID
- **Migration needed**: Use the version from 20250121 instead of 20250102

---

### 4. **Other Core Functions** (3 functions NOT JSON-only)

These have **ALREADY BEEN UPDATED** in `20250121000000_update_rpc_functions_for_flat_tables.sql`:

✅ **UPDATED**: `get_recent_progress(days_back, workout_name_param)`
✅ **UPDATED**: `get_exercise_progress(exercise_name, days_back, workout_name_param)`
✅ **UPDATED**: `calc_workout_history(date_override)`

---

## Dependency Summary

| Category | Count | Status |
|----------|-------|--------|
| Workout Day Manipulation | 6 | ❌ JSON-ONLY |
| Session Entry Manipulation | 2 | ❌ JSON-ONLY |
| Aggregation Functions | 1 | ⚠️ MIXED (needs 20250121 version) |
| **Total requiring refactoring** | **9** | **Requires action** |

---

## What These Functions Cannot Do

### ❌ Cannot work with flat table schema:
- Functions expecting `workouts` UUID and JSONB `days` structure
- Functions expecting `sessions` UUID and JSONB `entries` structure
- Any function directly manipulating JSONB using operators: `->`, `->>`, `||`, `jsonb_set()`, `jsonb_array_elements()`

### ✅ What they CAN work with:
- `workouts_flat`: Already has denormalized exercise data
- `sessions_flat`: Already has flattened set-by-set data
- Text-based keys: `workout_name` instead of UUID

---

## Recommended Migration Path

### Phase 1: Disable JSON-only functions (immediate)
```sql
-- DROP or RENAME these functions to prevent accidental use:
drop function if exists add_exercise_to_day(uuid, text, text, int, int, int, text, text);
drop function if exists remove_exercise_from_day(uuid, text, text);
drop function if exists update_workout_day_weight(uuid, text, int, int);
drop function if exists update_entry_weight(uuid, int, int);
drop function if exists update_entry_reps(uuid, int, int);
-- Keep create_workout, get_active_workout, get_workout_for_day for backward compatibility
-- Or provide deprecation warning
```

### Phase 2: Create flat-table versions (next sprint)
```
1. add_exercise_to_workout_flat() - Insert into workouts_flat
2. remove_exercise_from_workout_flat() - Delete from workouts_flat
3. update_exercise_weight_flat() - Update workouts_flat records
4. update_session_entry_weight_flat() - Update sessions_flat records
5. update_session_entry_reps_flat() - Update sessions_flat records
6. create_workout_flat() - Insert into workouts table + seed workouts_flat
7. get_active_workout_flat() - Read from workouts_flat
8. get_workout_for_day_flat() - Read from workouts_flat
```

### Phase 3: Update client code
- Replace all calls to JSON-version functions with flat-version equivalents
- Remove UUID-based parameter passing
- Update to use `workout_name` (text) instead

---

## Notes for Development

**Question**: Should `workouts` table be completely dropped?
- **Current Status**: Still exists (preserved in migration 20250110)
- **Only used by**: The JSON-only functions listed above
- **Recommendation**: Keep during transition period for backward compatibility, then drop in final release

**Question**: When should we migrate client code?
- **Immediate**: Stop using JSON-only functions in new code
- **Short-term**: Create flat-table versions alongside JSON versions
- **Long-term**: Deprecate and remove JSON versions once all clients migrated

