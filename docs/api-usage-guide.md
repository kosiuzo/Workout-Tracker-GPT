# Workout Tracker GPT - API Usage Guide

## Overview

This guide explains the strategic approach for using the Workout Tracker GPT API with flattened tables. Understanding when to use direct table access vs RPC functions will help you build efficient and maintainable applications.

## Table of Contents
- [API Strategy](#api-strategy)
- [Authentication](#authentication)
- [Reading Data (GET)](#reading-data-get)
- [Writing Data (RPC Functions)](#writing-data-rpc-functions)
- [Complete Workflows](#complete-workflows)
- [Advanced Queries](#advanced-queries)
- [Performance Tips](#performance-tips)

---

## API Strategy

### Two Approaches

The API provides two ways to interact with your workout data:

#### 1. **Direct Table Access** (via Supabase/PostgREST)
**Best for:** Reading data with flexible filtering

```bash
GET /workouts_flat?day_name=eq.monday&workout_is_active=eq.true
GET /sessions_flat?exercise_name=eq.Bench+Press&session_date=gte.2025-01-01
```

**Advantages:**
- Powerful URL-based query parameters
- Column selection (fetch only what you need)
- Built-in pagination and sorting
- Complex filtering with operators (eq, gt, lt, like, ilike, in, etc.)
- Great for analytics and reporting

**Use for:**
- Reading workout plans
- Querying session history
- Analyzing performance data
- Building reports and dashboards

#### 2. **RPC Functions** (stored procedures)
**Best for:** Creating, updating, or complex operations

```bash
POST /rpc/start_session
POST /rpc/log_set
POST /rpc/complete_session
```

**Advantages:**
- Input validation and error handling
- Multi-step operations in single call
- Consistent JSON response format
- Business logic encapsulation
- Maintains data integrity

**Use for:**
- Session management (create, complete)
- Set logging (create, update, delete)
- Operations requiring validation
- Multi-table updates

---

## Authentication

All API requests require authentication via the `apikey` header:

```bash
curl "https://your-project.supabase.co/rest/v1/workouts_flat" \
  -H "apikey: your-anon-key" \
  -H "Content-Type: application/json"
```

You can use either:
- **Anon key** - For public/anonymous access
- **Service role key** - For server-side operations (bypasses RLS)

---

## Reading Data (GET)

### When to Use Direct Table Access

✅ **Use direct GET when you need:**
- Flexible filtering
- Custom sorting
- Pagination
- Column selection
- Complex queries

❌ **Don't use GET for:**
- Creating or updating data
- Operations requiring validation
- Multi-step transactions

### workouts_flat - Reading Workout Plans

#### Get Today's Workout (if you know it's Monday)

```bash
curl "https://your-project.supabase.co/rest/v1/workouts_flat?workout_is_active=eq.true&day_name=eq.monday&order=exercise_order" \
  -H "apikey: your-key"
```

**Returns:**
```json
[
  {
    "id": "abc123",
    "workout_name": "Push/Pull/Legs v1",
    "day_name": "monday",
    "exercise_order": 0,
    "exercise_name": "Bench Press",
    "sets": 4,
    "reps": 8,
    "weight": 185,
    "superset_group": null,
    "exercise_notes": "Barbell, touch chest each rep"
  },
  ...
]
```

#### Get All Exercises for a Workout

```bash
curl "https://your-project.supabase.co/rest/v1/workouts_flat?workout_id=eq.{uuid}&order=day_name,exercise_order" \
  -H "apikey: your-key"
```

#### Find Workouts Containing an Exercise

```bash
curl "https://your-project.supabase.co/rest/v1/workouts_flat?exercise_name=eq.Bench+Press&select=workout_id,workout_name,day_name" \
  -H "apikey: your-key"
```

#### Get Superset Exercises

```bash
curl "https://your-project.supabase.co/rest/v1/workouts_flat?workout_id=eq.{uuid}&day_name=eq.monday&superset_group=eq.A&order=exercise_order" \
  -H "apikey: your-key"
```

#### Get Only Exercise Names and Target Weights

```bash
curl "https://your-project.supabase.co/rest/v1/workouts_flat?day_name=eq.wednesday&select=exercise_name,weight&workout_is_active=eq.true" \
  -H "apikey: your-key"
```

### sessions_flat - Reading Session Data

#### Get All Sets from a Session

```bash
curl "https://your-project.supabase.co/rest/v1/sessions_flat?session_id=eq.{uuid}&order=exercise_name,set_number" \
  -H "apikey: your-key"
```

**Returns:**
```json
[
  {
    "id": "set1-uuid",
    "session_id": "session-uuid",
    "session_date": "2025-01-06",
    "exercise_name": "Bench Press",
    "set_number": 1,
    "reps": 10,
    "weight": 185
  },
  ...
]
```

#### Get Exercise History for Last 30 Days

```bash
curl "https://your-project.supabase.co/rest/v1/sessions_flat?exercise_name=eq.Bench+Press&session_date=gte.2024-12-07&order=session_date.desc,set_number" \
  -H "apikey: your-key"
```

#### Get Today's Logged Sets

```bash
curl "https://your-project.supabase.co/rest/v1/sessions_flat?session_date=eq.2025-01-06&order=created_at" \
  -H "apikey: your-key"
```

#### Find Personal Records (Heaviest Weight)

```bash
curl "https://your-project.supabase.co/rest/v1/sessions_flat?exercise_name=eq.Squat&order=weight.desc&limit=1" \
  -H "apikey: your-key"
```

#### Get Exercise Volume by Date

```bash
curl "https://your-project.supabase.co/rest/v1/sessions_flat?exercise_name=eq.Deadlift&session_date=gte.2025-01-01&select=session_date,reps,weight" \
  -H "apikey: your-key"
```

### PostgREST Query Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `eq` | Equals | `?day_name=eq.monday` |
| `neq` | Not equals | `?weight=neq.0` |
| `gt` | Greater than | `?weight=gt.200` |
| `gte` | Greater than or equal | `?session_date=gte.2025-01-01` |
| `lt` | Less than | `?reps=lt.5` |
| `lte` | Less than or equal | `?set_number=lte.3` |
| `like` | Pattern match (case-sensitive) | `?exercise_name=like.*Press*` |
| `ilike` | Pattern match (case-insensitive) | `?exercise_name=ilike.*press*` |
| `in` | In list | `?day_name=in.(monday,wednesday,friday)` |
| `is` | Is null/true/false | `?superset_group=is.null` |

---

## Writing Data (RPC Functions)

### When to Use RPC Functions

✅ **Use RPC functions when you need to:**
- Create new sessions
- Log workout sets
- Update or delete sets
- Complete sessions
- Execute business logic

❌ **Don't try to:**
- Directly INSERT/UPDATE/DELETE on sessions_flat (it's auto-generated)
- Manually manipulate JSONB arrays in sessions table

### Session Management

#### Start a New Session

```bash
curl -X POST "https://your-project.supabase.co/rest/v1/rpc/start_session" \
  -H "apikey: your-key" \
  -H "Content-Type: application/json" \
  -d '{}'
```

**Response:**
```json
{
  "success": true,
  "message": "Session started successfully",
  "session_id": "new-session-uuid",
  "workout_id": "workout-uuid",
  "workout_name": "Push/Pull/Legs v1",
  "date": "2025-01-06"
}
```

**With Notes:**
```bash
curl -X POST "https://your-project.supabase.co/rest/v1/rpc/start_session" \
  -H "apikey: your-key" \
  -H "Content-Type: application/json" \
  -d '{"session_notes_param": "Morning workout, feeling strong"}'
```

**For Specific Date:**
```bash
curl -X POST "https://your-project.supabase.co/rest/v1/rpc/start_session" \
  -H "apikey: your-key" \
  -H "Content-Type: application/json" \
  -d '{"date_param": "2025-01-07"}'
```

#### Get Today's Session

```bash
curl -X POST "https://your-project.supabase.co/rest/v1/rpc/get_todays_session" \
  -H "apikey: your-key" \
  -H "Content-Type: application/json" \
  -d '{}'
```

**Response:**
```json
{
  "success": true,
  "session_id": "session-uuid",
  "workout_id": "workout-uuid",
  "workout_name": "Push/Pull/Legs v1",
  "date": "2025-01-06",
  "notes": "Great workout",
  "sets": [
    {
      "id": "set-uuid",
      "exercise_name": "Bench Press",
      "set_number": 1,
      "reps": 10,
      "weight": 185
    }
  ]
}
```

#### Complete Session

```bash
curl -X POST "https://your-project.supabase.co/rest/v1/rpc/complete_session" \
  -H "apikey: your-key" \
  -H "Content-Type: application/json" \
  -d '{
    "session_uuid": "session-uuid",
    "final_notes": "Excellent workout, hit all targets!"
  }'
```

**Response:**
```json
{
  "success": true,
  "message": "Session completed and history calculated",
  "session_id": "session-uuid",
  "date": "2025-01-06",
  "history_result": {...}
}
```

### Set Logging

#### Log a Single Set

```bash
curl -X POST "https://your-project.supabase.co/rest/v1/rpc/log_set" \
  -H "apikey: your-key" \
  -H "Content-Type: application/json" \
  -d '{
    "session_uuid": "session-uuid",
    "exercise_name_param": "Bench Press",
    "set_number_param": 1,
    "reps_param": 10,
    "weight_param": 185
  }'
```

**Response:**
```json
{
  "success": true,
  "message": "Set logged successfully",
  "session_id": "session-uuid",
  "exercise": "Bench Press",
  "set": 1,
  "reps": 10,
  "weight": 185
}
```

#### Log Multiple Sets at Once

```bash
curl -X POST "https://your-project.supabase.co/rest/v1/rpc/log_multiple_sets" \
  -H "apikey: your-key" \
  -H "Content-Type: application/json" \
  -d '{
    "session_uuid": "session-uuid",
    "sets_data": [
      {"exercise": "Bench Press", "set": 1, "reps": 10, "weight": 185},
      {"exercise": "Bench Press", "set": 2, "reps": 9, "weight": 185},
      {"exercise": "Bench Press", "set": 3, "reps": 8, "weight": 185},
      {"exercise": "Incline Press", "set": 1, "reps": 10, "weight": 60},
      {"exercise": "Incline Press", "set": 2, "reps": 10, "weight": 60}
    ]
  }'
```

**Response:**
```json
{
  "success": true,
  "message": "Logged 5 sets successfully",
  "session_id": "session-uuid",
  "sets_logged": 5
}
```

#### Update a Set

**Update Only Reps:**
```bash
curl -X POST "https://your-project.supabase.co/rest/v1/rpc/update_set" \
  -H "apikey: your-key" \
  -H "Content-Type: application/json" \
  -d '{
    "session_uuid": "session-uuid",
    "exercise_name_param": "Bench Press",
    "set_number_param": 2,
    "reps_param": 10
  }'
```

**Update Both Reps and Weight:**
```bash
curl -X POST "https://your-project.supabase.co/rest/v1/rpc/update_set" \
  -H "apikey: your-key" \
  -H "Content-Type: application/json" \
  -d '{
    "session_uuid": "session-uuid",
    "exercise_name_param": "Bench Press",
    "set_number_param": 2,
    "reps_param": 12,
    "weight_param": 195
  }'
```

#### Delete a Set

```bash
curl -X POST "https://your-project.supabase.co/rest/v1/rpc/delete_set" \
  -H "apikey: your-key" \
  -H "Content-Type: application/json" \
  -d '{
    "session_uuid": "session-uuid",
    "exercise_name_param": "Bench Press",
    "set_number_param": 5
  }'
```

### Workout Queries

#### Get Today's Workout

```bash
curl -X POST "https://your-project.supabase.co/rest/v1/rpc/get_todays_exercises_flat" \
  -H "apikey: your-key" \
  -H "Content-Type: application/json" \
  -d '{}'
```

**Response:**
```json
{
  "success": true,
  "workout_id": "workout-uuid",
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

#### Get Exercises for Specific Day

```bash
curl -X POST "https://your-project.supabase.co/rest/v1/rpc/get_exercises_for_day_flat" \
  -H "apikey: your-key" \
  -H "Content-Type: application/json" \
  -d '{"day_name_param": "wednesday"}'
```

### History & Analytics

#### Get Exercise History

```bash
curl -X POST "https://your-project.supabase.co/rest/v1/rpc/get_exercise_history_flat" \
  -H "apikey: your-key" \
  -H "Content-Type: application/json" \
  -d '{
    "exercise_name_param": "Bench Press",
    "days_back": 30
  }'
```

**Response:**
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

#### Get Workout Summary

```bash
curl -X POST "https://your-project.supabase.co/rest/v1/rpc/get_workout_summary_flat" \
  -H "apikey: your-key" \
  -H "Content-Type: application/json" \
  -d '{"session_uuid": "session-uuid"}'
```

**Response:**
```json
{
  "success": true,
  "session_id": "session-uuid",
  "workout_name": "Push/Pull/Legs v1",
  "date": "2025-01-06",
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
      "exercise_name": "Incline Press",
      "total_sets": 3,
      "total_reps": 29,
      "total_volume": 1740,
      "max_weight": 60,
      "avg_weight": 60
    }
  ]
}
```

---

## Complete Workflows

### Workflow 1: Starting and Logging a Workout

```bash
# 1. Get today's workout plan
curl -X POST "https://your-project.supabase.co/rest/v1/rpc/get_todays_exercises_flat" \
  -H "apikey: your-key" \
  -H "Content-Type: application/json" \
  -d '{}'

# Response shows: Bench Press (4x8 @ 185), Incline Press (3x10 @ 60), etc.

# 2. Start the session
curl -X POST "https://your-project.supabase.co/rest/v1/rpc/start_session" \
  -H "apikey: your-key" \
  -H "Content-Type: application/json" \
  -d '{"session_notes_param": "Morning workout"}'

# Response: {"session_id": "abc123..."}

# 3. Log sets as you go
curl -X POST "https://your-project.supabase.co/rest/v1/rpc/log_set" \
  -H "apikey: your-key" \
  -H "Content-Type: application/json" \
  -d '{
    "session_uuid": "abc123",
    "exercise_name_param": "Bench Press",
    "set_number_param": 1,
    "reps_param": 10,
    "weight_param": 185
  }'

# Continue logging sets...

# 4. Complete the session
curl -X POST "https://your-project.supabase.co/rest/v1/rpc/complete_session" \
  -H "apikey: your-key" \
  -H "Content-Type: application/json" \
  -d '{
    "session_uuid": "abc123",
    "final_notes": "Great workout, felt strong!"
  }'
```

### Workflow 2: Analyzing Progress

```bash
# 1. Get exercise history
curl -X POST "https://your-project.supabase.co/rest/v1/rpc/get_exercise_history_flat" \
  -H "apikey: your-key" \
  -H "Content-Type: application/json" \
  -d '{
    "exercise_name_param": "Bench Press",
    "days_back": 90
  }'

# 2. Find personal records (using direct access for custom query)
curl "https://your-project.supabase.co/rest/v1/sessions_flat?exercise_name=eq.Bench+Press&order=weight.desc&limit=5&select=session_date,reps,weight" \
  -H "apikey: your-key"

# 3. Calculate total volume over time (using direct access)
curl "https://your-project.supabase.co/rest/v1/sessions_flat?exercise_name=eq.Bench+Press&session_date=gte.2024-10-01&select=session_date,reps,weight" \
  -H "apikey: your-key"
```

### Workflow 3: Correcting Mistakes

```bash
# 1. Check what you logged
curl -X POST "https://your-project.supabase.co/rest/v1/rpc/get_todays_session" \
  -H "apikey: your-key" \
  -H "Content-Type: application/json" \
  -d '{}'

# 2. Update incorrect set
curl -X POST "https://your-project.supabase.co/rest/v1/rpc/update_set" \
  -H "apikey: your-key" \
  -H "Content-Type: application/json" \
  -d '{
    "session_uuid": "session-uuid",
    "exercise_name_param": "Bench Press",
    "set_number_param": 3,
    "reps_param": 8
  }'

# 3. Delete wrong set
curl -X POST "https://your-project.supabase.co/rest/v1/rpc/delete_set" \
  -H "apikey: your-key" \
  -H "Content-Type: application/json" \
  -d '{
    "session_uuid": "session-uuid",
    "exercise_name_param": "Bench Press",
    "set_number_param": 5
  }'
```

---

## Advanced Queries

### Using OR conditions

```bash
# Get exercises from Monday OR Friday
curl "https://your-project.supabase.co/rest/v1/workouts_flat?or=(day_name.eq.monday,day_name.eq.friday)&workout_is_active=eq.true" \
  -H "apikey: your-key"
```

### Aggregate Functions

PostgREST doesn't support aggregation directly, but you can use raw SQL queries or compute on client side.

**Client-side aggregation example (pseudo-code):**
```javascript
// Fetch data
const sets = await fetch('/sessions_flat?exercise_name=eq.Bench+Press&session_date=eq.2025-01-06')
  .then(r => r.json())

// Calculate totals
const totalVolume = sets.reduce((sum, set) => sum + (set.reps * set.weight), 0)
const totalReps = sets.reduce((sum, set) => sum + set.reps, 0)
```

### Pagination

```bash
# Get first 10 results
curl "https://your-project.supabase.co/rest/v1/sessions_flat?order=session_date.desc&limit=10" \
  -H "apikey: your-key"

# Get next 10 results
curl "https://your-project.supabase.co/rest/v1/sessions_flat?order=session_date.desc&limit=10&offset=10" \
  -H "apikey: your-key"
```

### Range Queries

```bash
# Get sessions from last week
curl "https://your-project.supabase.co/rest/v1/sessions_flat?session_date=gte.2024-12-30&session_date=lte.2025-01-06" \
  -H "apikey: your-key"
```

### Text Search

```bash
# Case-insensitive search for exercises containing "press"
curl "https://your-project.supabase.co/rest/v1/workouts_flat?exercise_name=ilike.*press*" \
  -H "apikey: your-key"
```

---

## Performance Tips

### 1. Use Column Selection

Only fetch the columns you need:

```bash
# ❌ Inefficient - fetches all columns
curl "https://your-project.supabase.co/rest/v1/sessions_flat?session_id=eq.{uuid}"

# ✅ Efficient - fetches only needed columns
curl "https://your-project.supabase.co/rest/v1/sessions_flat?session_id=eq.{uuid}&select=exercise_name,set_number,reps,weight"
```

### 2. Use Pagination

```bash
# Paginate large result sets
curl "https://your-project.supabase.co/rest/v1/sessions_flat?limit=50&offset=0"
```

### 3. Use RPC for Complex Operations

```bash
# ❌ Don't make multiple API calls
# Call 1: Get session
# Call 2: Update set 1
# Call 3: Update set 2
# Call 4: Calculate history

# ✅ Use batch RPC functions
curl -X POST "https://your-project.supabase.co/rest/v1/rpc/log_multiple_sets"
# Then:
curl -X POST "https://your-project.supabase.co/rest/v1/rpc/complete_session"
```

### 4. Cache Workout Plans

Workout plans don't change often, so cache them client-side:

```javascript
// Cache for the day
const cacheKey = `workout-${new Date().toDateString()}`
let workout = localStorage.getItem(cacheKey)

if (!workout) {
  workout = await fetch('/rpc/get_todays_exercises_flat').then(r => r.json())
  localStorage.setItem(cacheKey, JSON.stringify(workout))
}
```

### 5. Use Indexes Effectively

The flat tables have indexes on:
- `workout_flat`: workout_id, day_name, exercise_name, workout_is_active
- `sessions_flat`: session_id, workout_id, session_date, exercise_name

Filter on these columns for best performance.

---

## Error Handling

All RPC functions return consistent error format:

```json
{
  "success": false,
  "message": "Session not found",
  "session_id": "invalid-uuid"
}
```

Common errors:

| Error | Cause | Solution |
|-------|-------|----------|
| Session not found | Invalid session_id | Check session exists with get_todays_session |
| No active workout found | No workout is active | Set a workout as active |
| Session already exists | Duplicate session | Use existing session or choose different date |
| Set number must be positive | Invalid set_number | Use 1, 2, 3, etc. |
| Workout name is required | Missing parameter | Provide workout_name |

---

## Decision Tree

Use this flowchart to decide which API approach to use:

```
Are you READING data?
├─ YES → Do you need flexible filtering/sorting/pagination?
│   ├─ YES → Use direct GET on workouts_flat or sessions_flat
│   └─ NO → Use RPC function (e.g., get_todays_exercises_flat)
│
└─ NO (you're WRITING data) → Are you creating/updating/deleting sets?
    ├─ YES → Use RPC functions (log_set, update_set, delete_set)
    └─ NO → Are you managing sessions?
        ├─ YES → Use RPC functions (start_session, complete_session)
        └─ NO → Check if there's an appropriate RPC function
```

---

## Summary Table

| Operation | Approach | Endpoint |
|-----------|----------|----------|
| View today's workout | RPC (convenience) | POST /rpc/get_todays_exercises_flat |
| Query workout exercises | Direct GET | GET /workouts_flat?... |
| View exercise history | Direct GET | GET /sessions_flat?exercise_name=eq... |
| Start workout session | RPC (required) | POST /rpc/start_session |
| Log a set | RPC (required) | POST /rpc/log_set |
| Update a set | RPC (required) | POST /rpc/update_set |
| Delete a set | RPC (required) | POST /rpc/delete_set |
| Complete session | RPC (required) | POST /rpc/complete_session |
| Analyze progression | RPC or Direct GET | POST /rpc/get_exercise_history_flat or GET /sessions_flat?... |
| Get session summary | RPC | POST /rpc/get_workout_summary_flat |

---

## Next Steps

- Review the [OpenAPI Specification](./openapi-flat-tables.yaml)
- Check out the [Flat Table RPC Functions](./flat_table_rpc_functions.md)
- Read the [Table Structure Docs](./sessions_flat_table_structure.md)

For additional help, see the Supabase PostgREST documentation: https://postgrest.org/
