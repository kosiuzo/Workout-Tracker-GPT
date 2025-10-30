# Workout Tracker GPT - System Architecture

## Overview

The Workout Tracker GPT is a conversational workout tracking system that combines Supabase's powerful PostgreSQL database with OpenAI's Custom GPT capabilities. Users can track workouts, log sessions, and analyze progress through natural language interactions.

## Architecture Layers

```
┌─────────────────────────────────────┐
│        Custom GPT (OpenAI)          │  ← Natural Language Interface
├─────────────────────────────────────┤
│      OpenAPI 3.1 Specification      │  ← API Contract
├─────────────────────────────────────┤
│     Supabase REST API + RPC         │  ← API Layer
├─────────────────────────────────────┤
│   PostgreSQL + JSONB Storage        │  ← Data Layer
└─────────────────────────────────────┘
```

## Database Design

### Core Principles

1. **JSONB Flexibility**: Store complex workout structures in JSON for easy schema evolution
2. **Incremental Aggregation**: Calculate history only for changed dates, not full rescans
3. **Single Active Workout**: Unique constraint ensures only one workout plan is active
4. **Merge-Safe Updates**: All RPC functions use `ON CONFLICT DO UPDATE` for idempotency

### Table Structure

#### 1. `workouts`
**Purpose**: Store workout templates with flexible day/exercise structure

```sql
workouts (
  id uuid primary key,
  name text,
  description text,
  days jsonb,              -- {"monday": [...exercises], "tuesday": [...]}
  is_active boolean,       -- Only one can be true (unique constraint)
  created_at timestamp,
  updated_at timestamp
)
```

**JSONB Structure for `days`**:
```json
{
  "monday": [
    {
      "exercise": "Bench Press",
      "sets": 4,
      "reps": 8,
      "weight": 185,
      "superset_group": "A",  // Optional: group exercises together
      "notes": "Touch chest each rep"  // Optional
    }
  ]
}
```

**Key Features**:
- Unique index on `is_active = true` ensures single active workout
- JSONB allows flexible attributes (supersets, tempo, rest time, etc.)
- Day names are lowercase keys in the JSONB object

#### 2. `sessions`
**Purpose**: Log actual workout performance

```sql
sessions (
  id uuid primary key,
  workout_id uuid references workouts,
  date date,
  entries jsonb,           -- Array of set-by-set logs
  notes text,
  created_at timestamp,
  updated_at timestamp
)
```

**JSONB Structure for `entries`**:
```json
[
  {"exercise": "Bench Press", "set": 1, "reps": 10, "weight": 185},
  {"exercise": "Bench Press", "set": 2, "reps": 9, "weight": 185},
  {"exercise": "Incline Press", "set": 1, "reps": 10, "weight": 60}
]
```

**Key Features**:
- Set-by-set granularity for detailed tracking
- Can log partial workouts or incomplete sets
- Foreign key cascade deletes when workout is removed

#### 3. `exercise_history`
**Purpose**: Daily aggregated totals per exercise

```sql
exercise_history (
  id uuid primary key,
  workout_id uuid references workouts,
  exercise_name text,
  date date,
  total_sets int,
  total_reps int,
  total_volume int,        -- Sum of (weight × reps)
  max_weight int,
  avg_weight numeric,
  created_at timestamp,
  updated_at timestamp,
  unique(workout_id, exercise_name, date)
)
```

**Key Features**:
- Unique constraint prevents duplicate aggregations
- Updated incrementally via RPC functions
- Supports trend analysis per exercise

#### 4. `workout_history`
**Purpose**: Daily aggregated totals per workout

```sql
workout_history (
  id uuid primary key,
  workout_id uuid references workouts,
  date date,
  total_volume int,
  total_sets int,
  total_reps int,
  num_exercises int,
  duration_minutes int,    -- Optional
  created_at timestamp,
  updated_at timestamp,
  unique(workout_id, date)
)
```

**Key Features**:
- Rolled up from `exercise_history`
- Shows overall workout intensity trends
- Unique constraint per workout per day

## RPC Functions

### Core Operations

#### 1. `set_active_workout(workout_uuid)`
**Purpose**: Activate a workout plan (deactivates all others)

**Logic**:
```sql
1. Deactivate all workouts (UPDATE is_active = false)
2. Activate target workout (UPDATE is_active = true WHERE id = workout_uuid)
3. Return success with workout details
```

**Returns**: JSON with success status and workout name

#### 2. `calc_exercise_history(date_override)`
**Purpose**: Aggregate session data into exercise history for a specific date

**Logic**:
```sql
1. Extract all entries from sessions for the date
2. Group by workout_id, exercise_name
3. Calculate totals (sets, reps, volume, max/avg weight)
4. UPSERT into exercise_history with ON CONFLICT DO UPDATE
```

**Key Points**:
- Idempotent - safe to run multiple times
- Incremental - only processes specified date
- Merge-safe - updates existing records

#### 3. `calc_workout_history(date_override)`
**Purpose**: Roll up exercise history into workout totals

**Logic**:
```sql
1. Aggregate exercise_history for the date
2. Group by workout_id
3. Sum volumes, sets, reps; count distinct exercises
4. UPSERT into workout_history
```

**Dependencies**: Must run after `calc_exercise_history`

#### 4. `calc_all_history(date_override)`
**Purpose**: Run both aggregations in one transaction

**Logic**:
```sql
1. Call calc_exercise_history(date_override)
2. Call calc_workout_history(date_override)
3. Return combined results
```

**Use Case**: Primary aggregation function for GPT integration

### JSON Manipulation Functions

#### 5. `update_workout_day_weight(workout_uuid, day_name, exercise_name, new_weight)`
**Purpose**: Update a specific exercise's weight in workout template

**Logic**:
```sql
1. Extract day's exercise array from workout.days
2. Find exercise by name
3. Update weight field using jsonb_set
4. Replace entire day array in workout
```

**Returns**: JSON with old and new weights

#### 6. `update_entry_weight(session_uuid, exercise_name, set_number, new_weight)`
**Purpose**: Update a specific set's weight in a session

**Logic**:
```sql
1. Extract entries array from session
2. Find entry by exercise name and set number
3. Update weight field
4. Replace entire entries array
```

#### 7. `update_entry_reps(session_uuid, exercise_name, set_number, new_reps)`
**Purpose**: Update a specific set's reps

**Similar logic to update_entry_weight**

#### 8. `add_exercise_to_day(workout_uuid, day_name, exercise_name, ...)`
**Purpose**: Add new exercise to a workout day

**Logic**:
```sql
1. Build exercise JSONB object
2. Get current day's exercises (or [] if day doesn't exist)
3. Append new exercise
4. Update workout.days with modified array
```

#### 9. `remove_exercise_from_day(workout_uuid, day_name, exercise_name)`
**Purpose**: Remove exercise from workout day

**Logic**:
```sql
1. Get current day's exercises
2. Filter out matching exercise
3. Update workout.days with filtered array
```

### Query Helper Functions

#### 10. `get_active_workout()`
**Purpose**: Retrieve currently active workout

**Returns**: JSON with full workout details

#### 11. `get_workout_for_day(day_name, workout_uuid?)`
**Purpose**: Get exercises for a specific day

**Logic**:
```sql
1. If no workout_uuid, use active workout
2. Extract days->day_name from workout
3. Return exercise array
```

#### 12. `get_recent_progress(days_back, workout_uuid?)`
**Purpose**: Summary of recent workout history

**Returns**: Array of workout_history records

#### 13. `get_exercise_progress(exercise_name, days_back, workout_uuid?)`
**Purpose**: Track progression for specific exercise

**Returns**: Array of exercise_history records

## Data Flow Patterns

### Creating a Workout
```
GPT → POST /workouts → Supabase
                      ↓
              Insert into workouts table
                      ↓
              Return workout with ID
```

### Logging a Session
```
GPT → POST /sessions → Supabase
                      ↓
              Insert session with entries
                      ↓
              (Optional) Auto-trigger calc_all_history
                      ↓
              Update exercise_history & workout_history
```

### Querying Progress
```
GPT → POST /rpc/get_recent_progress → Supabase
                                     ↓
                      Query workout_history table
                                     ↓
                      Join with workouts for names
                                     ↓
                      Return aggregated JSON
```

### Updating Template Weight
```
GPT → POST /rpc/update_workout_day_weight → Supabase
                                           ↓
                      Extract day from workout.days
                                           ↓
                      Find and update exercise weight
                                           ↓
                      Replace day in JSONB
                                           ↓
                      Return old/new weights
```

## Indexing Strategy

### Performance Indexes

```sql
-- Fast active workout lookup
idx_workouts_active on workouts(is_active) WHERE is_active = true

-- Session date queries
idx_sessions_date on sessions(date DESC)
idx_sessions_workout_date on sessions(workout_id, date DESC)

-- Exercise history queries
idx_exercise_history_exercise_date on exercise_history(exercise_name, date DESC)
idx_exercise_history_workout_date on exercise_history(workout_id, date DESC)

-- Workout history queries
idx_workout_history_workout_date on workout_history(workout_id, date DESC)
```

### Why These Indexes?

1. **Active workout index**: GPT frequently asks "what's my workout today?"
2. **Date DESC indexes**: Most queries are recent-first (last 7 days, last month)
3. **Composite indexes**: Support filtering by workout + date range efficiently
4. **Exercise name index**: Enable quick "show me my bench press progress" queries

## Scalability Considerations

### Current Architecture (Single User)
- RLS enabled but set to allow all for anon key
- No user authentication required
- All data accessible via anon key

### Future Multi-User Support

**Schema Changes Needed**:
```sql
-- Add user_id to all tables
ALTER TABLE workouts ADD COLUMN user_id uuid REFERENCES auth.users;
ALTER TABLE sessions ADD COLUMN user_id uuid REFERENCES auth.users;

-- Update RLS policies
CREATE POLICY "Users can only see own workouts"
  ON workouts FOR ALL
  USING (auth.uid() = user_id);

-- Add user_id indexes
CREATE INDEX idx_workouts_user ON workouts(user_id);
CREATE INDEX idx_sessions_user ON sessions(user_id);
```

**Benefits of Current Design**:
- Easy to add `user_id` later without breaking existing logic
- RPC functions already return JSON, easy to filter by user
- Indexes already support composite queries

## Security Model

### Current (Single User)
```sql
-- RLS enabled but permissive for development
CREATE POLICY "Allow all for anon users" ON workouts
  FOR ALL USING (true) WITH CHECK (true);
```

### Production Ready
```sql
-- Lock down to authenticated users only
CREATE POLICY "Users manage own workouts" ON workouts
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- RPC functions check user_id
CREATE OR REPLACE FUNCTION set_active_workout(workout_uuid uuid)
RETURNS json AS $$
BEGIN
  -- Add user validation
  IF NOT EXISTS (
    SELECT 1 FROM workouts
    WHERE id = workout_uuid AND user_id = auth.uid()
  ) THEN
    RETURN json_build_object('error', 'Not authorized');
  END IF;
  -- ... rest of function
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

## Custom GPT Integration

### OpenAPI Configuration

**Base URL**: `https://your-project.supabase.co/rest/v1`

**Authentication**:
```yaml
security:
  - apiKey: []

securitySchemes:
  apiKey:
    type: apiKey
    in: header
    name: apikey
```

**Key Headers**:
- `apikey`: Your Supabase anon key
- `Prefer: return=representation` (for POST/PATCH operations)

### GPT Intent Mapping

| User Intent | API Call | Example |
|-------------|----------|---------|
| "What's my workout today?" | `GET /rpc/get_workout_for_day` | `{"day_name": "monday"}` |
| "Log my bench press session" | `POST /sessions` | Create session with entries |
| "Show my progress this week" | `POST /rpc/get_recent_progress` | `{"days_back": 7}` |
| "Update bench press to 195" | `POST /rpc/update_workout_day_weight` | Update template weight |
| "Activate my push/pull plan" | `POST /rpc/set_active_workout` | Set workout as active |

## Extension Points

### Adding New Features

**1. Supersets**
- Already supported via `superset_group` field
- GPT can group exercises with same superset_group letter

**2. Rest Timers**
- Add `rest_seconds` field to exercise JSONB
- GPT can remind users when rest is complete

**3. Progressive Overload**
- Calculate from exercise_history
- Add RPC function: `suggest_next_weight(exercise_name)`

**4. Workout Templates**
- Add `template_id` to workouts
- Create `workout_templates` table for presets

**5. Analytics Dashboard**
- Read from history tables
- Calculate PRs, volume trends, consistency
- Add RPC: `get_analytics_summary()`

## Performance Characteristics

### Expected Query Times (Single User)
- Get active workout: ~10ms
- Log session: ~50ms
- Calculate history (one day): ~100-200ms
- Get recent progress (7 days): ~30ms
- Update template weight: ~20ms

### Bottlenecks to Watch
1. **Large JSONB arrays**: If days have >50 exercises, consider normalizing
2. **History calculation**: With hundreds of sessions, add date range limits
3. **JSONB querying**: Ensure GIN indexes if searching within JSONB

### Optimization Strategies
```sql
-- Add GIN index for JSONB searches
CREATE INDEX idx_workouts_days_gin ON workouts USING gin(days);

-- Partition history tables by date (future)
CREATE TABLE exercise_history_2025 PARTITION OF exercise_history
  FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
```

## Deployment Checklist

### Development
- [x] Supabase CLI installed
- [x] Local Supabase running: `supabase start`
- [x] Migrations applied: `supabase db reset`
- [x] Sample data seeded
- [x] Test RPC functions via Supabase Studio

### Production
- [ ] Create Supabase project
- [ ] Apply migrations: `supabase db push`
- [ ] Get anon key from project settings
- [ ] Update OpenAPI spec with production URL
- [ ] Configure Custom GPT with OpenAPI spec
- [ ] Test all GPT interactions
- [ ] Monitor API usage and set up alerts

## Troubleshooting

### Common Issues

**Issue**: "No active workout found"
- **Cause**: No workout has `is_active = true`
- **Fix**: `SELECT set_active_workout('<workout_id>')`

**Issue**: "History is empty"
- **Cause**: Haven't run `calc_all_history()`
- **Fix**: `SELECT calc_all_history(current_date)`

**Issue**: "Exercise not found on day"
- **Cause**: Day name case mismatch or typo
- **Fix**: Day names are lowercase in JSONB: "monday" not "Monday"

**Issue**: "Session entries not saving"
- **Cause**: Invalid JSONB format
- **Fix**: Ensure entries is array: `[{...}, {...}]` not `{...}`

## Maintenance

### Regular Tasks
1. **Nightly history aggregation** (optional, via pg_cron)
2. **Backup database** (Supabase auto-backups for paid plans)
3. **Monitor API usage** (Supabase dashboard)

### Schema Evolution
- Add new JSONB fields without migrations
- Use versioned migrations for table changes
- Test RPC function changes in staging first

## Conclusion

This architecture provides:
- ✅ Flexible data model via JSONB
- ✅ Efficient incremental aggregations
- ✅ GPT-friendly RPC interface
- ✅ Easy extension path for new features
- ✅ Production-ready security model (with user_id)
- ✅ Optimized for single-user simplicity, scalable to multi-user
