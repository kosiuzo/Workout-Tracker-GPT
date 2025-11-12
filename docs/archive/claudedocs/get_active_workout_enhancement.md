# Get Active Workout & Today's Workout Enhancement

## Summary

Updated the `get_active_workout` RPC function to automatically include the current day of the week, and created a new `get_todays_workout` convenience function for a single-call solution to get today's workout. Both functions use Eastern Time (America/New_York) to ensure accurate day detection regardless of UTC time.

## Problem

ChatGPT has difficulty accessing the current date/time, which makes it challenging to automatically determine which day's workout plan to show when a user asks "What's my workout today?"

## Solution

Created two complementary solutions:

### 1. Enhanced `get_active_workout()` function:
- Calculates the current day of the week using PostgreSQL's `current_timestamp at time zone 'America/New_York'`
- Returns the day name in lowercase (e.g., "monday", "tuesday", etc.)
- Includes this in the response as a `current_day` field
- Returns full workout details for all days of the week

### 2. New `get_todays_workout()` convenience function:
- Single-call solution for "What's my workout today?"
- Automatically detects current day using Eastern Time
- Calls `get_workout_for_day()` with the current day
- Returns ONLY today's exercises (not the full week)

## Database Changes

**Migration**: `20250106000000_update_get_active_workout_with_current_day.sql`

### get_active_workout() Response:
```json
{
  "success": true,
  "workout": {
    "id": "uuid",
    "name": "workout name",
    "days": {
      "monday": [...],
      "tuesday": [...],
      "friday": [...]
    }
  },
  "current_day": "friday"
}
```

### get_todays_workout() Response:
```json
{
  "success": true,
  "workout_id": "uuid",
  "workout_name": "Simple 3-Day",
  "day": "friday",
  "exercises": [
    {
      "exercise": "Deadlift",
      "sets": 4,
      "reps": 5,
      "weight": 315
    }
  ]
}
```

Or if no exercises for today:
```json
{
  "success": false,
  "workout_id": "uuid",
  "workout_name": "Simple 3-Day",
  "day": "friday",
  "message": "No exercises found for friday"
}
```

## API Changes

**OpenAPI Version**: Updated from 14.0.0 to 16.0.0

### Endpoint 1: `POST /rpc/get_active_workout`
- Enhanced response schema with `current_day` field
- Timezone clearly documented as America/New_York
- Added note recommending `get_todays_workout` for simpler use case

### Endpoint 2: `POST /rpc/get_todays_workout` (NEW)
- Recommended endpoint for "What's my workout today?"
- Single-call solution
- Returns only today's exercises
- Includes workout metadata (id, name, day)

## Usage for ChatGPT

### Recommended Approach (Simple)

**User**: "What's my workout today?"

**ChatGPT**:
1. Calls `POST /rpc/get_todays_workout` with empty body `{}`
2. Receives today's exercises directly
3. Shows the user their workout for today

### Alternative Approach (Full Context)

**User**: "Show me my full workout plan and what I should do today"

**ChatGPT**:
1. Calls `POST /rpc/get_active_workout` with empty body `{}`
2. Receives both the full week's workout plan AND `current_day: "friday"`
3. Shows full week schedule with today highlighted
4. Can lookup `workout.days[current_day]` for today's specific exercises

## Testing

Tested locally and confirmed:
- `get_active_workout()` returns correct current day using Eastern Time ("friday" when UTC is Saturday)
- `get_todays_workout()` correctly detects current day and returns today's exercises
- Timezone conversion working properly (America/New_York)
- OpenAPI specification is valid (version 16.0.0)
- Response structures match schema for both endpoints
- Proper handling when no exercises exist for today (returns success: false with message)

## Benefits

- **Eliminates date confusion**: No need for ChatGPT to determine the current date
- **Timezone accuracy**: Uses Eastern Time (America/New_York) instead of UTC for correct day detection
- **Single-call convenience**: `get_todays_workout()` provides optimal UX for most common use case
- **Flexible options**: Can get just today OR full week + today depending on user needs
- **Server-side accuracy**: All date/time logic centralized in the database
- **Consistent behavior**: Timezone conversion handled uniformly across both functions
- **Backwards compatible**: Doesn't break existing functionality, extends it
- **Clear documentation**: OpenAPI spec guides ChatGPT to use the right endpoint for each scenario
