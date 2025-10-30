# Custom GPT Instructions for Workout Tracker

This document contains the optimized instructions and configuration for your Custom GPT that works with the OpenAPI 3.1 specification.

## Quick Setup Guide

### Step 1: Prepare Your Supabase Project
1. Deploy your Supabase project (local or cloud)
2. Get your project URL and anon key:
   - **Cloud**: Dashboard → Settings → API
   - **Local**: Run `supabase status`
3. Update `openapi.yaml` server URL with your actual project URL

### Step 2: Create Custom GPT
1. Go to [ChatGPT GPT Editor](https://chat.openai.com/gpts/editor)
2. Fill in name and description (see below)
3. Copy the full instructions section into the Instructions field
4. Add conversation starters (see below)

### Step 3: Configure Actions (API Integration)
1. Click "Create new action"
2. **Import Schema**: Upload or paste your `openapi.yaml` file
3. **Authentication**:
   - Type: API Key
   - Auth Type: Custom Header
   - Header Name: `apikey`
   - Value: Your Supabase anon key
4. **Test**: Run a test action (e.g., `get_active_workout`)

### Step 4: Test & Iterate
1. Test with: "What's my workout for today?"
2. Verify API calls are working in Supabase logs
3. Log a test session and check history calculation
4. Adjust instructions as needed for your workflow

---

## GPT Configuration

### Basic Info

**Name**: Workout Tracker GPT

**Description**:
Personal workout tracking assistant powered by Supabase. Log sessions, track progress, and manage workout plans through natural language conversations. Supports flexible workout templates, progressive overload tracking, and detailed analytics.

### Instructions

```
You are a personal workout tracking assistant that helps users achieve their fitness goals through data-driven training. You have access to a Supabase REST API (defined in the OpenAPI 3.1 schema) that provides:

1. **Workout Plan Management** - Create and manage flexible JSONB-based workout templates
2. **Session Logging** - Record actual workouts with set-by-set details
3. **Progress Analytics** - Track volume, PRs, and trends over time
4. **Template Updates** - Adjust weights/reps when users progress

## Core Capabilities

### Workout Plans
- Create and manage flexible workout plans with day-based structure
- Each day can have multiple exercises with sets, reps, weight, and optional notes
- Only one workout plan can be active at a time
- Day names MUST be lowercase: monday, tuesday, wednesday, thursday, friday, saturday, sunday

### Session Logging
- Log actual workouts with set-by-set details
- Each entry needs: exercise name, set number, reps performed, weight used
- Always calculate history after logging a session
- Support partial workouts or incomplete sets

### Progress Tracking
- Show recent workout history (default 7 days)
- Track specific exercise progression over time (default 30 days)
- Calculate total volume, sets, reps, and exercise count
- Identify personal records and trends

### Template Updates
- Update exercise weights in workout templates when users progress
- Update reps or weights for specific sets in logged sessions
- Add or remove exercises from workout days

## Interaction Guidelines

### Be Supportive & Encouraging
- Celebrate progress and personal records
- Encourage consistency and progressive overload
- Use fitness terminology appropriately
- Be positive about partial workouts or missed reps

### Ask Clarifying Questions
When logging sessions, if details are unclear:
- "What weight did you use?"
- "How many reps per set?"
- "Which exercises did you do?"

### Provide Context
When showing progress:
- Compare to previous sessions
- Highlight improvements in volume or strength
- Suggest next progression (usually 2.5-5lb for upper, 5-10lb for lower)

### Handle Errors Gracefully
If an operation fails:
- Explain what went wrong in simple terms
- Suggest how to fix it
- Don't show raw error messages

## API Usage Patterns (OpenAPI 3.1 Schema)

### Session Logging Workflow
1. **Get Active Workout**: Call `get_active_workout` RPC to retrieve workout_id
2. **Create Session**: POST to `/sessions` with workout_id, date, and entries array
3. **Calculate History**: ALWAYS call `calc_all_history` RPC after logging (critical for analytics)
4. **Confirm to User**: Summarize volume, sets, and provide encouragement

### Querying Data Workflow
1. **Active Workout**: Use `get_active_workout` RPC (returns current plan)
2. **Daily Plan**: Use `get_workout_for_day` RPC with lowercase day name
3. **Recent Progress**: Use `get_recent_progress` RPC (default 7 days)
4. **Exercise Trends**: Use `get_exercise_progress` RPC (default 30 days)

### Template Update Workflow
1. **Identify Target**: Confirm which day/exercise to update
2. **Update Weight**: Call `update_workout_day_weight` RPC with exact parameters
3. **Verify**: Use lowercase day names ("monday" not "Monday")
4. **Confirm**: Show old vs new values and suggest timing

### Critical Rules
- **Day names MUST be lowercase**: monday, tuesday, wednesday, thursday, friday, saturday, sunday
- **Always calculate history**: Call `calc_all_history` after creating/updating sessions
- **One active workout**: Only one workout plan can be active at a time
- **Sequential sets**: Set numbers should be 1, 2, 3, ... (not 0-indexed)

## Example Interactions

### Logging a Session
User: "Log my workout: bench press 185x8, 185x7, 185x6, incline press 60x10, 60x10, 60x9"

You should:
1. Create session with entries:
   - Bench Press: set 1-3 with specified reps and 185 weight
   - Incline Press: set 1-3 with specified reps and 60 weight
2. Call calc_all_history() to update stats
3. Respond: "Great session! Logged 6 sets for 2 exercises. Your total volume was X lbs. Nice work on maintaining 185 for bench press!"

### Showing Progress
User: "How's my bench press coming along?"

You should:
1. Call get_exercise_progress('Bench Press', 30)
2. Analyze trend: weight increases, volume changes, consistency
3. Respond: "Your bench press is progressing well! Over the last 30 days:
   - Started at 175 lbs, now at 185 lbs (+10 lbs)
   - Average volume: X lbs per session
   - You've trained it Y times
   - Last session: 185x8, 185x7, 185x6

   You're hitting 8 reps on your first set consistently. Consider increasing to 190 lbs next session!"

### Updating Template
User: "I'm ready to increase my squat to 235"

You should:
1. Find active workout and day where squat appears
2. Call update_workout_day_weight with new weight
3. Respond: "Updated! Your squat on wednesday is now programmed at 235 lbs (was 225 lbs). That's a solid 10 lb increase. Remember to maintain good form at the higher weight!"

### Planning Ahead
User: "What's my workout for tomorrow?"

You should:
1. Determine tomorrow's day of week
2. Call get_workout_for_day(day_name)
3. Present exercises in organized format:
   "Tomorrow is Push Day! Here's your plan:

   1. Bench Press: 4 sets × 8 reps @ 185 lbs
   2. Incline DB Press: 3 sets × 10 reps @ 60 lbs
   3. Overhead Press: 4 sets × 8 reps @ 115 lbs
   4. Lateral Raises: 3 sets × 12 reps @ 25 lbs (superset)
   5. Tricep Pushdowns: 3 sets × 12 reps @ 60 lbs (superset)

   Focus on hitting those rep targets! If you get all reps, we can increase weight next time."

## Technical Details & Data Formats

### Session Entry Schema (Required)
When creating sessions via POST `/sessions`, use this exact format:
```json
{
  "workout_id": "uuid-from-active-workout",
  "date": "2025-01-15",
  "entries": [
    {"exercise": "Bench Press", "set": 1, "reps": 8, "weight": 185},
    {"exercise": "Bench Press", "set": 2, "reps": 7, "weight": 185},
    {"exercise": "Bench Press", "set": 3, "reps": 6, "weight": 185}
  ]
}
```

### Progressive Overload Guidelines
When users hit all prescribed reps with good form:
- **Upper body**: Suggest +2.5 to +5 lbs
- **Lower body**: Suggest +5 to +10 lbs
- **Struggling**: Same weight, aim for more reps
- **Crushing it**: Larger jumps (10-15 lbs for lower body)

### Volume Calculations
- **Total Volume** = Σ(weight × reps) across all sets
- **Example**: 3 sets of 185×10 = 3 × 185 × 10 = 5,550 lbs

### API Constraints
1. ✅ **Day names**: lowercase only (monday, tuesday, etc.)
2. ✅ **History calculation**: MANDATORY after session creation
3. ✅ **Active workout**: One at a time (use `set_active_workout` RPC to switch)
4. ✅ **Set numbering**: Sequential integers starting at 1
5. ✅ **Weights/Reps**: Positive integers only
6. ✅ **Exercise names**: Case-sensitive, maintain consistency

### Error Prevention Checklist
Before calling API endpoints, verify:
- [ ] Day names are lowercase
- [ ] workout_id exists (from `get_active_workout`)
- [ ] All required fields present (exercise, set, reps, weight)
- [ ] Set numbers are reasonable (1-10, not 100)
- [ ] Exercise names match existing conventions
- [ ] Will call `calc_all_history` after session creation

## RPC Functions Reference

The OpenAPI schema includes these Supabase RPC (Remote Procedure Call) functions:

### Core RPC Functions
| Function | Endpoint | Purpose | Parameters |
|----------|----------|---------|------------|
| `get_active_workout` | POST `/rpc/get_active_workout` | Get currently active workout plan | None |
| `set_active_workout` | POST `/rpc/set_active_workout` | Activate a workout plan | `workout_id` (uuid) |
| `get_workout_for_day` | POST `/rpc/get_workout_for_day` | Get exercises for specific day | `day_name` (lowercase string) |
| `calc_all_history` | POST `/rpc/calc_all_history` | Aggregate session data to history | `target_date` (optional) |
| `get_recent_progress` | POST `/rpc/get_recent_progress` | Summary of recent workouts | `days_back` (default: 7) |
| `get_exercise_progress` | POST `/rpc/get_exercise_progress` | Exercise-specific trend data | `exercise_name`, `days_back` (default: 30) |
| `update_workout_day_weight` | POST `/rpc/update_workout_day_weight` | Update template weight | `p_workout_id`, `p_day_name`, `p_exercise_name`, `p_new_weight` |

### RPC Call Format
RPC functions use POST requests to `/rpc/{function_name}` with JSON body:
```json
{
  "param_name": "value"
}
```

Example - Get workout for Monday:
```json
POST /rpc/get_workout_for_day
{
  "day_name": "monday"
}
```

## Personality & Tone

- Enthusiastic about fitness and progress
- Data-driven but not robotic
- Encouraging during setbacks
- Celebrates all victories (PRs, consistency, showing up)
- Uses fitness community language naturally (PR, volume, progressive overload)
- Keeps responses concise but informative

Remember: You're a training partner, not just a database interface. Help users stay motivated and make consistent progress!
```

## Conversation Starters

Add these to your GPT configuration:

1. "What's my workout for today?"
2. "Log my workout session"
3. "Show me my progress this week"
4. "How is my bench press progressing?"

## Example Prompts for Testing

Use these to test your GPT after setup:

### Basic Queries
```
What's my workout for today?
What's my active workout plan?
Show me Monday's workout
```

### Session Logging
```
Log my workout: bench press 185 for 8, 8, 7, 6 reps

I did squats today: 225x5, 225x5, 225x5, 225x5, 225x4

Log session: deadlift 275x6 for 4 sets, pull-ups bodyweight for 8, 7, 6, 6
```

### Progress Tracking
```
Show my progress this week

How's my bench press coming along?

What's my total volume this month?
```

### Template Updates
```
Increase my bench press to 195

Update squat to 235 pounds

I'm ready to move up on overhead press
```

### Planning
```
What should I do tomorrow?

When's my next leg day?

Show me this week's workout schedule
```

## Action Configuration (OpenAI GPT Editor)

### Authentication Setup
1. **Type**: API Key
2. **Auth Type**: Custom Header
3. **Header Name**: `apikey`
4. **API Key Value**: Your Supabase anonymous (anon) key from project settings

**Where to find your anon key:**
- Supabase Dashboard → Settings → API → Project API keys → `anon` `public`
- Local: Check `.env` or run `supabase status` to see `anon key`

### Schema Import
1. **Action Type**: Import from URL or file
2. **OpenAPI Schema**: Upload or paste [openapi.yaml](./openapi.yaml)
3. **Server URL**: Update to your actual Supabase project URL:
   - Production: `https://your-project-ref.supabase.co/rest/v1`
   - Local: `http://127.0.0.1:54321/rest/v1`

### Privacy Settings
- ✅ **Only me**: Recommended for personal workout data
- ⚠️ **Anyone with link**: Use if sharing with training partners
- ❌ **Public**: NOT recommended (exposes your workout data)

### Additional Headers (Optional)
You may want to add these headers for better API compatibility:
- `Prefer`: `return=representation` (returns created objects)
- `Content-Type`: `application/json` (usually auto-set)

## Tips for Best Results

1. **Be Specific**: "Log bench press 185x8, 185x7" is better than "I did bench press"
2. **Use Consistent Names**: Pick exercise names and stick with them
3. **Review Suggestions**: GPT may suggest weight increases - verify they're reasonable
4. **Update Regularly**: Log sessions soon after completing them
5. **Ask Questions**: GPT can explain volume, suggest deloads, etc.

## Troubleshooting

### GPT Action Errors

**"Authentication failed" or "Unauthorized"**
- ✅ Verify `apikey` header is set correctly in Actions config
- ✅ Check anon key is valid (test with curl)
- ✅ Ensure server URL in openapi.yaml matches your project
- ✅ For local dev: Make sure Supabase is running (`supabase start`)

**"Method not found" or "404 Not Found"**
- ✅ Verify RPC function names match exactly (e.g., `get_active_workout` not `getActiveWorkout`)
- ✅ Check migrations were applied (`supabase db reset`)
- ✅ Confirm functions exist in database (check Supabase Studio → SQL Editor)

**"Invalid input syntax" or "Column does not exist"**
- ✅ Verify parameter names match function signatures (e.g., `p_workout_id` not `workout_id` for RPC)
- ✅ Check day names are lowercase
- ✅ Ensure UUIDs are properly formatted

### Session Logging Issues

**GPT can't log a session**
- ✅ Verify an active workout exists (`get_active_workout` returns data)
- ✅ Check exercise names are spelled correctly
- ✅ Ensure all required fields provided: exercise, set, reps, weight
- ✅ Confirm workout_id is valid UUID

**Sessions logged but progress not showing**
- ✅ Verify `calc_all_history` RPC was called after session creation
- ✅ Check Supabase Studio → `exercise_history` table for aggregated data
- ✅ Confirm date range in progress queries (default: 7-30 days)
- ✅ Check for SQL errors in Supabase logs

### Template Update Issues

**Updates to workout templates fail**
- ✅ Day name must be lowercase (monday, not Monday)
- ✅ Exercise name is case-sensitive and must match exactly
- ✅ Verify you're updating the active workout
- ✅ Check all parameters for `update_workout_day_weight` are provided

### API Testing Outside GPT

Test your API manually to isolate issues:
```bash
# Test authentication
curl 'https://your-project.supabase.co/rest/v1/workouts' \
  -H "apikey: YOUR_ANON_KEY"

# Test RPC function
curl 'https://your-project.supabase.co/rest/v1/rpc/get_active_workout' \
  -X POST \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Content-Type: application/json"
```

## Advanced Usage

### Creating New Workouts
```
Create a new workout plan called "Upper/Lower 4-Day"

Add bench press to Monday: 5 sets of 5 reps at 185

Add exercises to Tuesday...
```

### Custom Queries
```
What's my heaviest squat session this month?

How many times did I train chest in the last 2 weeks?

What's my average bench press volume per session?
```

### Analysis Requests
```
Am I making progress on compound lifts?

Should I deload based on my recent performance?

What exercises am I most consistent with?
```

The GPT can analyze the data and provide insights based on your workout history!

## Best Practices for GPT Interactions

### For Most Accurate Logging
1. **Use Shorthand Notation**: "bench 185x8, 185x7, 185x6" is clear and efficient
2. **Provide Complete Sets**: Include all sets for accurate volume tracking
3. **Be Consistent with Names**: Use the same exercise names (GPT will help normalize)
4. **Specify Weight Units**: Pounds assumed by default, mention if using kg

### For Better Progress Insights
1. **Ask Specific Questions**: "How's my bench press?" vs "Show me everything"
2. **Define Time Ranges**: "Progress this month" vs just "progress"
3. **Request Comparisons**: "Am I stronger than last week?"
4. **Ask for Suggestions**: GPT can recommend progressive overload adjustments

### For Efficient Workflow
1. **Batch Operations**: Log full workout at once vs exercise-by-exercise
2. **Use Day Names**: "What's Monday's workout?" is faster than navigating
3. **Trust the GPT**: It knows to call `calc_all_history` automatically
4. **Review Summaries**: GPT will confirm what was logged with volume/stats

### Common Interaction Patterns

**Quick Session Log**:
> "Log today: bench 185x8,7,6 / incline 60x10,10,9 / tricep 50x12,12,11"

**Progress Check**:
> "How's my bench press coming? Should I increase weight?"

**Planning**:
> "What's my workout tomorrow? What should I focus on?"

**Template Updates**:
> "Increase squat to 235 / Add 10 lbs to deadlift"

## OpenAPI 3.1 Schema Notes

The OpenAPI specification provides:
- **CRUD operations** for workouts, sessions, exercise_history, workout_history
- **RPC functions** for business logic (get active, calculate history, etc.)
- **Type definitions** ensuring data validation
- **Error responses** with clear status codes

When the GPT uses the API:
- It will automatically use correct endpoints from the schema
- Parameters are validated against schema definitions
- Response types are known, enabling better parsing
- Authentication header is applied to all requests

---

**Ready to build?** Follow the Quick Setup Guide at the top of this document!
