# Workout Tracker GPT - Setup & Deployment Guide

## Quick Start (Local Development)

### Prerequisites
- Node.js 18+ installed
- Docker Desktop installed and running
- Supabase CLI installed
- Git

### Install Supabase CLI

```bash
# macOS/Linux
brew install supabase/tap/supabase

# Windows (PowerShell)
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase

# Verify installation
supabase --version
```

### Step 1: Clone and Initialize

```bash
# Navigate to project directory
cd Workout-Tracker-GPT

# Start Supabase local development
supabase start
```

**Expected Output**:
```
Started supabase local development setup.

         API URL: http://127.0.0.1:54321
          DB URL: postgresql://postgres:postgres@127.0.0.1:54322/postgres
      Studio URL: http://127.0.0.1:54323
    Inbucket URL: http://127.0.0.1:54324
        anon key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
service_role key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Save these values** - you'll need the API URL and anon key!

### Step 2: Apply Migrations

```bash
# Reset database and apply all migrations + seed data
supabase db reset
```

This will:
1. Create all tables (workouts, sessions, exercise_history, workout_history)
2. Create all RPC functions
3. Load sample data (Push/Pull/Legs workout plan with sessions)

### Step 3: Verify Installation

```bash
# Open Supabase Studio in browser
open http://127.0.0.1:54323
```

**Check in Studio**:
1. Navigate to **Table Editor**
2. You should see: `workouts`, `sessions`, `exercise_history`, `workout_history`
3. Click on `workouts` - should see 1 row (Push/Pull/Legs v1)
4. Click on `sessions` - should see 3 sample sessions

### Step 4: Test RPC Functions

In Supabase Studio, go to **SQL Editor** and run:

```sql
-- Get active workout
SELECT * FROM get_active_workout();

-- Get workout for today
SELECT * FROM get_workout_for_day('monday');

-- Get recent progress
SELECT * FROM get_recent_progress(7);

-- Get exercise progress
SELECT * FROM get_exercise_progress('Bench Press', 30);
```

All queries should return valid JSON responses.

### Step 5: Test REST API

```bash
# Set your anon key from step 1
export SUPABASE_ANON_KEY="your-anon-key-here"

# Test getting workouts
curl "http://127.0.0.1:54321/rest/v1/workouts?is_active=eq.true" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json"

# Test RPC function
curl "http://127.0.0.1:54321/rest/v1/rpc/get_workout_for_day" \
  -X POST \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"day_name": "monday"}'
```

If you see workout data, your local setup is working! ✅

---

## Production Deployment

### Step 1: Create Supabase Project

1. Go to [https://supabase.com](https://supabase.com)
2. Click **"New Project"**
3. Fill in:
   - **Name**: Workout Tracker GPT
   - **Database Password**: (generate strong password and save it)
   - **Region**: Choose closest to you
   - **Pricing Plan**: Free tier is sufficient for personal use

4. Click **"Create new project"**
5. Wait ~2 minutes for project to initialize

### Step 2: Get Project Credentials

In your Supabase project dashboard:

1. Click **"Settings"** (gear icon in sidebar)
2. Click **"API"**
3. **Copy and save**:
   - **Project URL** (e.g., `https://abcdefghijk.supabase.co`)
   - **Project API Key** > **anon** > **public** (starts with `eyJhbG...`)

### Step 3: Link Local Project to Production

```bash
# Login to Supabase
supabase login

# Link to your project
supabase link --project-ref your-project-ref

# Find your project-ref in the URL: https://supabase.com/dashboard/project/[project-ref]
```

### Step 4: Push Database Schema

```bash
# Push migrations to production
supabase db push

# Verify migrations were applied
supabase db remote commit
```

**Expected Output**:
```
✓ All migrations applied successfully
✓ Remote database is up to date
```

### Step 5: Seed Production Data (Optional)

```bash
# Connect to production database
supabase db remote commit

# Run seed file manually in Supabase Studio:
# 1. Go to SQL Editor
# 2. Copy contents of supabase/seed.sql
# 3. Paste and run
```

**Alternative**: Skip sample data for production, create your own workouts.

### Step 6: Test Production API

```bash
# Set production credentials
export SUPABASE_URL="https://your-project-ref.supabase.co"
export SUPABASE_ANON_KEY="your-production-anon-key"

# Test connection
curl "$SUPABASE_URL/rest/v1/workouts" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json"
```

If you see `[]` (empty array) or your seeded workouts, production is ready! ✅

---

## Custom GPT Configuration

### Step 1: Prepare OpenAPI Spec

1. Open [openapi.yaml](./openapi.yaml) in your project
2. **Update the production server URL**:

```yaml
servers:
  - url: https://your-project-ref.supabase.co/rest/v1
    description: Production
```

Replace `your-project-ref` with your actual project reference.

### Step 2: Create Custom GPT

1. Go to [https://chat.openai.com/gpts/editor](https://chat.openai.com/gpts/editor)
2. Click **"Create a GPT"**

**Configure Tab**:
- **Name**: Workout Tracker
- **Description**: Personal workout tracking assistant that helps you log sessions, track progress, and manage workout plans.
- **Instructions**:

```
You are a personal workout tracking assistant. You help users:

1. Log workout sessions with set-by-set details
2. Track progress over time for specific exercises
3. Manage workout plans and templates
4. Provide summaries of recent training

## Key Capabilities
- Create and manage workout plans with flexible day/exercise structures
- Log actual workout sessions with reps, sets, and weights
- Track exercise progression over time
- Summarize recent workout history
- Update workout templates when users progress

## Interaction Style
- Be encouraging and supportive
- Use fitness terminology appropriately
- Ask clarifying questions when session details are unclear
- Automatically calculate volume and suggest progressive overload

## Data Handling
- Always use the RPC functions for complex operations
- When logging sessions, create detailed entries with exercise, set, reps, weight
- Calculate history after logging sessions
- Day names are lowercase: monday, tuesday, etc.

## Progressive Overload
- When users ask "what should I lift next?", check their exercise history
- Suggest 2.5-5lb increases for upper body, 5-10lb for lower body
- Consider rep ranges: if they hit all reps, suggest weight increase
```

**Conversation Starters** (optional):
- "What's my workout for today?"
- "Log my workout session"
- "Show me my progress this week"
- "Update my bench press weight"

### Step 3: Configure Actions

Click **"Create new action"**:

1. **Authentication**: Select **"API Key"**
   - **Auth Type**: API Key
   - **API Key**: Paste your Supabase anon key
   - **Auth Type**: Custom
   - **Custom Header Name**: `apikey`

2. **Schema**: Import from URL or paste
   - Click **"Import from URL"** (if hosting openapi.yaml)
   - **OR** paste entire contents of [openapi.yaml](./openapi.yaml)

3. **Test**: Click **"Test"** to validate the schema

4. **Available Actions**: You should see all operations:
   - `listWorkouts`
   - `createSession`
   - `getActiveWorkout`
   - `getWorkoutForDay`
   - `calcAllHistory`
   - etc.

### Step 4: Test Your GPT

In the **Preview** pane, try these prompts:

```
User: "What's my workout for today?"
Expected: GPT calls get_workout_for_day, shows your Monday/Tuesday/etc exercises

User: "Log my workout: bench press 185x8, 185x7, 185x6, and incline press 60x10, 60x9"
Expected: GPT creates session with proper entries format

User: "Show my progress this week"
Expected: GPT calls get_recent_progress, summarizes volume/sets/reps

User: "Update bench press to 195 pounds"
Expected: GPT calls update_workout_day_weight
```

### Step 5: Publish (Optional)

- Click **"Publish"** in top-right
- Choose **"Only me"** (private use)
- **OR** share with link if you want others to use it

---

## Usage Guide

### Creating Your First Workout

```
You: "Create a new workout plan called 'Upper/Lower Split'"

GPT: Creates workout via POST /workouts

You: "Add bench press to Monday: 4 sets of 8 reps at 185 pounds"

GPT: Calls add_exercise_to_day with parameters
```

### Logging a Session

```
You: "Log my workout from today"

GPT: "What exercises did you do?"

You: "Bench press: 185 for 8, 8, 7, 6 reps. Incline press: 60 for 10, 10, 9"

GPT: Creates session with entries:
[
  {"exercise": "Bench Press", "set": 1, "reps": 8, "weight": 185},
  {"exercise": "Bench Press", "set": 2, "reps": 8, "weight": 185},
  {"exercise": "Bench Press", "set": 3, "reps": 7, "weight": 185},
  {"exercise": "Bench Press", "set": 4, "reps": 6, "weight": 185},
  {"exercise": "Incline Press", "set": 1, "reps": 10, "weight": 60},
  {"exercise": "Incline Press", "set": 2, "reps": 10, "weight": 60},
  {"exercise": "Incline Press", "set": 3, "reps": 9, "weight": 60}
]

Then calls: calc_all_history() to update statistics
```

### Tracking Progress

```
You: "How is my bench press progressing?"

GPT: Calls get_exercise_progress('Bench Press', 30)
Shows: dates, weights, volumes, trends

You: "Summarize my last week"

GPT: Calls get_recent_progress(7)
Shows: total volume, sets, exercises per day
```

### Updating Templates

```
You: "I'm ready to increase bench press to 195"

GPT: Calls update_workout_day_weight
Updates: monday's bench press from 185 → 195
Confirms: "Updated Bench Press on Monday from 185 to 195 lbs"
```

---

## Troubleshooting

### Issue: "Failed to load API"

**Cause**: OpenAPI spec has invalid URL or authentication

**Fix**:
1. Verify `servers[0].url` in openapi.yaml matches your Supabase URL
2. Check API key is correct in GPT Actions settings
3. Test API manually with curl (see Step 6 of Production Deployment)

### Issue: "No active workout found"

**Cause**: No workout has `is_active = true`

**Fix**:
```sql
-- In Supabase Studio SQL Editor
SELECT set_active_workout('your-workout-id');

-- Or update directly
UPDATE workouts SET is_active = true WHERE id = 'your-workout-id';
```

### Issue: "Day not found in workout"

**Cause**: Day names must be lowercase

**Fix**: Always use lowercase day names:
- ✅ `monday`, `tuesday`, `wednesday`
- ❌ `Monday`, `MONDAY`, `mon`

### Issue: "History is empty"

**Cause**: Haven't run `calc_all_history()` after logging sessions

**Fix**: GPT should automatically call this, but you can manually run:
```sql
SELECT calc_all_history(current_date);
```

### Issue: "Session entries format error"

**Cause**: Entries must be JSON array with required fields

**Fix**: Ensure format:
```json
[
  {"exercise": "name", "set": 1, "reps": 10, "weight": 100}
]
```

All fields (`exercise`, `set`, `reps`, `weight`) are required.

### Issue: Local Supabase won't start

**Cause**: Docker not running or ports already in use

**Fix**:
```bash
# Check Docker is running
docker ps

# Stop Supabase and restart
supabase stop
supabase start

# If ports in use, check config.toml for port conflicts
```

---

## Maintenance

### Backing Up Data

**Local Development**:
```bash
# Dump database
supabase db dump -f backup.sql

# Restore from backup
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres < backup.sql
```

**Production**:
- Supabase Pro/Team plans include automatic daily backups
- Free tier: Export manually via Studio > Database > Backups

### Updating Schema

**Local Development**:
```bash
# Create new migration
supabase migration new add_new_feature

# Edit the migration file in supabase/migrations/
# Then apply
supabase db reset
```

**Production**:
```bash
# Push new migrations
supabase db push

# Verify
supabase db remote commit
```

### Monitoring

**Supabase Dashboard**:
1. Go to **Reports** to see API usage
2. Check **Database** > **Roles** for connection info
3. Review **Logs** for errors

**Set Up Alerts**:
- Configure email alerts for API rate limits
- Monitor database size (Free tier: 500MB)

---

## Advanced Configuration

### Adding pg_cron for Nightly Aggregation

```sql
-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule nightly history calculation at 2 AM
SELECT cron.schedule(
  'nightly_history_calc',
  '0 2 * * *',
  $$SELECT calc_all_history(current_date)$$
);

-- Verify scheduled jobs
SELECT * FROM cron.job;
```

### Multi-User Setup

**Add user_id to all tables**:
```sql
-- Create migration: supabase migration new add_user_id

ALTER TABLE workouts ADD COLUMN user_id uuid REFERENCES auth.users(id);
ALTER TABLE sessions ADD COLUMN user_id uuid REFERENCES auth.users(id);

-- Update RLS policies
DROP POLICY "Allow all for anon users" ON workouts;

CREATE POLICY "Users manage own workouts" ON workouts
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Add indexes
CREATE INDEX idx_workouts_user ON workouts(user_id);
CREATE INDEX idx_sessions_user ON sessions(user_id);
```

### Custom Domain

1. Go to Supabase **Settings** > **API**
2. Set up **Custom Domain** (requires paid plan)
3. Update OpenAPI spec with custom domain
4. Update GPT Actions with new URL

---

## Cost Estimation

### Free Tier Limits (Supabase)
- **Database**: 500MB storage
- **Bandwidth**: 5GB egress
- **API Requests**: Unlimited (with rate limits)

**Estimated Usage (Single User)**:
- Database: ~10-50MB for 1 year of data
- API Calls: ~100-500/day
- **Verdict**: Free tier is sufficient ✅

### Paid Plans (Optional)
- **Pro** ($25/month): 8GB storage, 50GB bandwidth, point-in-time recovery
- **Team** ($599/month): For teams, enhanced security

### OpenAI Costs
- Custom GPTs require **ChatGPT Plus** ($20/month)
- API calls to Supabase are free (within Supabase limits)

---

## Next Steps

### After Setup
1. ✅ Verify local development works
2. ✅ Deploy to Supabase production
3. ✅ Configure Custom GPT
4. ✅ Test all interactions
5. ✅ Start logging your workouts!

### Enhancements to Consider
- Add workout templates library
- Implement progressive overload suggestions
- Create analytics dashboard
- Add exercise PR tracking
- Enable workout sharing (multi-user)

### Getting Help
- **Supabase Docs**: [https://supabase.com/docs](https://supabase.com/docs)
- **OpenAPI Spec**: [https://swagger.io/specification/](https://swagger.io/specification/)
- **Custom GPT Guide**: [https://help.openai.com/en/articles/8554397-creating-a-gpt](https://help.openai.com/en/articles/8554397-creating-a-gpt)

---

**You're all set! Start tracking your workouts with natural language. 💪**
