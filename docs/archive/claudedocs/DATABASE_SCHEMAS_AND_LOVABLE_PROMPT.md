# Workout Tracker Database Schemas & Lovable UI Prompt

## Database Schemas

### 1. WORKOUTS Table
**Purpose**: Stores workout templates with all days, exercises, and metadata

```sql
CREATE TABLE workouts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  days JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_active BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
```

**Constraints**:
- Only one active workout allowed at a time (unique index on `is_active` when true)

**Sample Data**:
```json
{
  "id": "00000000-0000-0000-0000-000000000001",
  "name": "Push/Pull/Legs v1",
  "description": "Classic PPL split focusing on progressive overload",
  "is_active": true,
  "days": {
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
        "exercise": "Incline Dumbbell Press",
        "sets": 3,
        "reps": 10,
        "weight": 60,
        "superset_group": null,
        "notes": "45-degree angle"
      }
    ],
    "tuesday": [
      {
        "exercise": "Deadlift",
        "sets": 4,
        "reps": 6,
        "weight": 275,
        "superset_group": null,
        "notes": "Conventional stance"
      }
    ]
  }
}
```

---

### 2. SESSIONS Table
**Purpose**: Logs what was actually performed in a workout session

```sql
CREATE TABLE sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workout_id UUID REFERENCES workouts(id) ON DELETE CASCADE,
  date DATE NOT NULL DEFAULT current_date,
  entries JSONB NOT NULL DEFAULT '[]'::jsonb,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
```

**Sample Data**:
```json
{
  "id": "10000000-0000-0000-0000-000000000001",
  "workout_id": "00000000-0000-0000-0000-000000000001",
  "date": "2025-10-28",
  "notes": "Great session, felt strong on bench",
  "entries": [
    {"exercise": "Bench Press", "set": 1, "reps": 8, "weight": 185},
    {"exercise": "Bench Press", "set": 2, "reps": 8, "weight": 185},
    {"exercise": "Bench Press", "set": 3, "reps": 7, "weight": 185},
    {"exercise": "Bench Press", "set": 4, "reps": 6, "weight": 185},
    {"exercise": "Incline Dumbbell Press", "set": 1, "reps": 10, "weight": 60},
    {"exercise": "Incline Dumbbell Press", "set": 2, "reps": 10, "weight": 60}
  ]
}
```

---

### 3. EXERCISE_HISTORY Table
**Purpose**: Aggregated daily totals per workout per exercise

```sql
CREATE TABLE exercise_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workout_id UUID REFERENCES workouts(id) ON DELETE CASCADE,
  exercise_name TEXT NOT NULL,
  date DATE NOT NULL,
  total_sets INT NOT NULL DEFAULT 0,
  total_reps INT NOT NULL DEFAULT 0,
  total_volume INT NOT NULL DEFAULT 0,
  max_weight INT NOT NULL DEFAULT 0,
  avg_weight NUMERIC(10,2),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  UNIQUE (workout_id, exercise_name, date)
);
```

**Sample Data**:
```json
{
  "id": "20000000-0000-0000-0000-000000000001",
  "workout_id": "00000000-0000-0000-0000-000000000001",
  "exercise_name": "Bench Press",
  "date": "2025-10-28",
  "total_sets": 4,
  "total_reps": 29,
  "total_volume": 5365,
  "max_weight": 185,
  "avg_weight": 185.00
}
```

---

### 4. WORKOUT_HISTORY Table
**Purpose**: Aggregated daily totals per workout (rolled up from exercise_history)

```sql
CREATE TABLE workout_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workout_id UUID REFERENCES workouts(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  total_volume INT NOT NULL DEFAULT 0,
  total_sets INT NOT NULL DEFAULT 0,
  total_reps INT NOT NULL DEFAULT 0,
  num_exercises INT NOT NULL DEFAULT 0,
  duration_minutes INT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  UNIQUE (workout_id, date)
);
```

**Sample Data**:
```json
{
  "id": "30000000-0000-0000-0000-000000000001",
  "workout_id": "00000000-0000-0000-0000-000000000001",
  "date": "2025-10-28",
  "total_volume": 24535,
  "total_sets": 17,
  "total_reps": 164,
  "num_exercises": 5,
  "duration_minutes": 75
}
```

---

## Entity Relationship Diagram

```
workouts (1) ──────┬──────> (many) sessions
    │              │
    │              │
    │              └──────> (many) exercise_history
    │                              │
    │                              │
    └─────────────────────────────> (many) workout_history
```

---

## Lovable Prompt for Minimalist UI

Copy and paste this into Lovable:

---

**Build a minimalist workout tracker web app with the following requirements:**

### Core Features

1. **Dashboard View**
   - Display today's workout from the active workout plan
   - Show progress cards: total volume, sets, reps for current week
   - Minimalist card design with subtle shadows and clean typography
   - Use a calming color palette (slate grays, subtle blues)

2. **Today's Workout Interface**
   - Show exercises for today based on the current day of the week
   - Display planned sets, reps, and weight for each exercise
   - Quick-log interface: tap to record each set with actual weight and reps
   - Visual indicators for superset groupings
   - Session notes field at the bottom
   - "Complete Workout" button that saves to sessions table

3. **Workout Plan Management**
   - View all workout plans
   - Create new workout plan with day-by-day exercises
   - Edit existing plans
   - Set one plan as active (only one active at a time)
   - Delete plans
   - JSONB structure for days with exercises array

4. **Progress & History**
   - Calendar view showing workout days
   - Exercise history charts showing progress over time
   - Volume, weight, and rep trends per exercise
   - Weekly/monthly summary statistics

5. **Session History**
   - List of past workout sessions
   - Click to view detailed set-by-set logs
   - Edit past sessions if needed
   - Session notes display

### Design Guidelines

- **Ultra-minimalist aesthetic**: Clean, spacious layouts with generous whitespace
- **Typography**: Use system fonts, clear hierarchy, 16px+ body text
- **Colors**: Neutral grays (#F8F9FA, #E9ECEF, #DEE2E6) with accent color (#4F46E5 or similar)
- **Cards**: Subtle shadows (shadow-sm), rounded corners (rounded-lg)
- **Buttons**: Clear primary/secondary distinction, appropriate sizing
- **Forms**: Clean inputs with proper labels and validation
- **Mobile-first**: Fully responsive, touch-friendly targets (min 44px)
- **Loading states**: Skeleton loaders for async data
- **Icons**: Use Lucide React icons sparingly

### Technical Stack

- **Frontend**: React with TypeScript
- **Styling**: Tailwind CSS
- **Database**: Supabase (PostgreSQL)
- **State**: React Query for server state
- **Forms**: React Hook Form with Zod validation
- **Charts**: Recharts for progress visualization
- **Date handling**: date-fns

### Database Schema (Supabase)

```typescript
// workouts table
{
  id: uuid,
  name: string,
  description: string,
  days: jsonb, // {monday: [{exercise, sets, reps, weight, superset_group, notes}]}
  is_active: boolean,
  created_at: timestamp,
  updated_at: timestamp
}

// sessions table
{
  id: uuid,
  workout_id: uuid (FK),
  date: date,
  entries: jsonb, // [{exercise, set, reps, weight}]
  notes: string,
  created_at: timestamp,
  updated_at: timestamp
}

// exercise_history table
{
  id: uuid,
  workout_id: uuid (FK),
  exercise_name: string,
  date: date,
  total_sets: int,
  total_reps: int,
  total_volume: int,
  max_weight: int,
  avg_weight: numeric,
  created_at: timestamp,
  updated_at: timestamp
}

// workout_history table
{
  id: uuid,
  workout_id: uuid (FK),
  date: date,
  total_volume: int,
  total_sets: int,
  total_reps: int,
  num_exercises: int,
  duration_minutes: int,
  created_at: timestamp,
  updated_at: timestamp
}
```

### Key User Flows

1. **Starting a Workout**
   - Open app → See today's workout
   - Tap exercise → Log each set (weight, reps)
   - Visual checkmarks as sets complete
   - Add session notes → Complete workout

2. **Creating a Workout Plan**
   - Navigate to Plans → New Plan
   - Enter name and description
   - For each day: Add exercises with sets/reps/weight
   - Mark supersets with grouping letters (A, B, C)
   - Save and optionally set as active

3. **Viewing Progress**
   - Navigate to Progress
   - Select exercise from dropdown
   - View chart showing weight/volume trends
   - Toggle between weekly/monthly views

### API Endpoints (Supabase RPC if needed)

- `get_active_workout()` - Returns active workout with today's exercises
- `create_session(workout_id, date, entries, notes)` - Logs workout session
- `calc_all_history(date)` - Calculates exercise and workout history
- `get_exercise_trend(exercise_name, weeks)` - Returns progress data

### Success Criteria

- Clean, distraction-free interface
- Workout logging takes < 30 seconds per exercise
- Zero cognitive load: obvious next action at each step
- Smooth animations and transitions
- Fast load times (< 2s)
- Works offline with optimistic updates
- Accessible (WCAG 2.1 AA minimum)

Build this with extreme attention to simplicity, performance, and user experience. Every element should serve a clear purpose. No clutter.

---

## Additional Context for Lovable

### Sample Workout Flow

**User opens app on Monday:**
1. Dashboard shows "Today: Push Day"
2. Card displays 5 exercises from the monday array in the active workout's days JSONB
3. User taps "Bench Press"
4. Quick-log modal appears with 4 empty set slots
5. User enters: Set 1 → 185lbs × 8 reps → Tap checkmark
6. Repeat for all sets
7. Move to next exercise
8. At end: "Complete Workout" → Saves to sessions table with entries array
9. Background job calculates exercise_history and workout_history aggregations

### Data Relationships

- Each workout has ONE active status (unique constraint)
- Sessions reference workout_id (cascade delete)
- History tables are computed from sessions (can be regenerated)
- Days JSONB allows flexible workout structure without rigid schema
- Superset groups use null or letter codes (A, B, C) to group exercises

### Performance Considerations

- Index on workouts.is_active for fast active workout lookup
- Index on sessions.date for history queries
- Aggregate history tables prevent slow joins on large session data
- JSONB gin indexes for efficient days/entries queries
