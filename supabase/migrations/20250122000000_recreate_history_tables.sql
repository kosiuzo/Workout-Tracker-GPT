-- =====================================================
-- Recreate History Aggregation Tables
-- =====================================================
-- These tables were dropped during migration but are still needed
-- for the aggregation functions calc_exercise_history and calc_workout_history

-- =====================================================
-- 1. EXERCISE_HISTORY TABLE
-- =====================================================
-- Aggregated exercise statistics by workout, exercise, and date

create table if not exists exercise_history (
  id uuid primary key default gen_random_uuid(),
  workout_id uuid not null references workouts(id) on delete cascade,
  exercise_name text not null,
  date date not null,
  total_sets int,
  total_reps int,
  total_volume numeric,
  max_weight numeric,
  avg_weight numeric,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),
  
  -- Ensure one record per exercise per workout per date
  unique(workout_id, exercise_name, date)
);

-- =====================================================
-- 2. WORKOUT_HISTORY TABLE
-- =====================================================
-- Aggregated workout statistics by workout and date

create table if not exists workout_history (
  id uuid primary key default gen_random_uuid(),
  workout_id uuid not null references workouts(id) on delete cascade,
  date date not null,
  total_volume numeric,
  total_sets int,
  total_reps int,
  num_exercises int,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),
  
  -- Ensure one record per workout per date
  unique(workout_id, date)
);

-- =====================================================
-- 3. INDEXES
-- =====================================================

create index if not exists idx_exercise_history_workout_date
  on exercise_history(workout_id, date desc);

create index if not exists idx_exercise_history_exercise_date
  on exercise_history(exercise_name, date desc);

create index if not exists idx_workout_history_date
  on workout_history(date desc);

create index if not exists idx_workout_history_workout_date
  on workout_history(workout_id, date desc);

-- =====================================================
-- 4. COMMENTS
-- =====================================================

comment on table exercise_history is 'Aggregated exercise statistics computed from sessions_flat for performance tracking';
comment on table workout_history is 'Aggregated workout statistics computed from exercise_history for session summaries';

