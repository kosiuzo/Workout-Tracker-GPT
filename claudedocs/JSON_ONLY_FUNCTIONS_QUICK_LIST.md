# JSON-Only RPC Functions - Quick Reference

## Functions That ONLY Work With JSON Tables

### ❌ DO NOT USE - These will fail with flat table schema

| Function | Purpose | Old Tables | Status |
|----------|---------|-----------|--------|
| `add_exercise_to_day()` | Add exercise to workout day | workouts (JSONB days) | ❌ JSON-ONLY |
| `remove_exercise_from_day()` | Remove exercise from day | workouts (JSONB days) | ❌ JSON-ONLY |
| `update_workout_day_weight()` | Update exercise weight in day | workouts (JSONB days) | ❌ JSON-ONLY |
| `update_entry_weight()` | Update set weight in session | sessions (JSONB entries) | ❌ JSON-ONLY |
| `update_entry_reps()` | Update set reps in session | sessions (JSONB entries) | ❌ JSON-ONLY |
| `create_workout()` | Create new workout | workouts (JSONB days) | ❌ JSON-ONLY |
| `get_active_workout()` | Get active workout | workouts (JSONB days) | ❌ JSON-ONLY |
| `get_workout_for_day()` | Get workout exercises for day | workouts (JSONB days) | ❌ JSON-ONLY |

## Functions Already Updated (Use These)

### ✅ USE THESE - Updated for flat table schema

| Function | Purpose | Status |
|----------|---------|--------|
| `get_recent_progress(days_back, workout_name)` | Get recent workout history | ✅ UPDATED |
| `get_exercise_progress(exercise_name, days_back, workout_name)` | Get exercise history | ✅ UPDATED |
| `calc_exercise_history(date_override)` | Aggregate exercise data | ✅ UPDATED (20250121) |
| `calc_workout_history(date_override)` | Aggregate workout data | ✅ UPDATED (20250121) |
| `calc_all_history(date_override)` | Aggregate all history | ✅ UPDATED (calls 20250121 versions) |

## Complete JSON-Only Function List

```
1. add_exercise_to_day(UUID) → manipulates JSONB days
2. remove_exercise_from_day(UUID) → manipulates JSONB days
3. update_workout_day_weight(UUID) → manipulates JSONB days
4. update_entry_weight(UUID) → manipulates JSONB entries
5. update_entry_reps(UUID) → manipulates JSONB entries
6. create_workout() → creates workouts with empty JSONB days
7. get_active_workout() → reads workouts JSONB days
8. get_workout_for_day(UUID) → reads workouts JSONB days
```

## Key Differences

### Old JSON Version (DO NOT USE)
```sql
-- References workouts table with JSONB
SELECT workouts.days->day_name FROM workouts WHERE id = uuid;
UPDATE workouts SET days = jsonb_set(...) WHERE id = uuid;
```

### New Flat Version (USE THIS)
```sql
-- References workouts_flat table with denormalized rows
SELECT * FROM workouts_flat WHERE workout_name = name AND day_name = day;
INSERT INTO workouts_flat (...) VALUES (...);
UPDATE workouts_flat SET weight = ? WHERE workout_name = name AND day_name = day AND exercise_name = exercise;
```

## Action Items

- [ ] Create flat-table versions of the 8 JSON-only functions
- [ ] Update client code to use new flat-table functions instead
- [ ] Remove or deprecate JSON-only functions
- [ ] Drop workouts/sessions tables once migration complete

