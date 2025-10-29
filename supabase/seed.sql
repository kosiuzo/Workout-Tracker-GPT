-- =====================================================
-- Workout Tracker GPT v1.0 - Seed Data
-- =====================================================
-- Sample data for testing and demonstration
-- Creates a Push/Pull/Legs workout plan with sample sessions
-- =====================================================

-- Clear existing data (for development/testing)
truncate table workout_history cascade;
truncate table exercise_history cascade;
truncate table sessions cascade;
truncate table workouts cascade;

-- =====================================================
-- 1. CREATE SAMPLE WORKOUT PLAN
-- =====================================================
-- Push/Pull/Legs (PPL) split - a popular 6-day routine

insert into workouts (id, name, description, days, is_active)
values (
  '00000000-0000-0000-0000-000000000001',
  'Push/Pull/Legs v1',
  'Classic PPL split focusing on progressive overload. Push (chest, shoulders, triceps), Pull (back, biceps), Legs (quads, hamstrings, calves).',
  '{
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
      },
      {
        "exercise": "Overhead Press",
        "sets": 4,
        "reps": 8,
        "weight": 115,
        "superset_group": null,
        "notes": "Strict form, no leg drive"
      },
      {
        "exercise": "Lateral Raises",
        "sets": 3,
        "reps": 12,
        "weight": 25,
        "superset_group": "A",
        "notes": "Dumbbells, control the eccentric"
      },
      {
        "exercise": "Tricep Pushdowns",
        "sets": 3,
        "reps": 12,
        "weight": 60,
        "superset_group": "A",
        "notes": "Rope attachment"
      }
    ],
    "tuesday": [
      {
        "exercise": "Deadlift",
        "sets": 4,
        "reps": 6,
        "weight": 275,
        "superset_group": null,
        "notes": "Conventional stance, focus on form"
      },
      {
        "exercise": "Pull-ups",
        "sets": 4,
        "reps": 8,
        "weight": 0,
        "superset_group": null,
        "notes": "Bodyweight, full ROM"
      },
      {
        "exercise": "Barbell Rows",
        "sets": 4,
        "reps": 10,
        "weight": 155,
        "superset_group": null,
        "notes": "Pendlay style, explosive pull"
      },
      {
        "exercise": "Face Pulls",
        "sets": 3,
        "reps": 15,
        "weight": 40,
        "superset_group": "B",
        "notes": "Rope attachment, high cable"
      },
      {
        "exercise": "Hammer Curls",
        "sets": 3,
        "reps": 12,
        "weight": 35,
        "superset_group": "B",
        "notes": "Dumbbells, alternating arms"
      }
    ],
    "wednesday": [
      {
        "exercise": "Squat",
        "sets": 5,
        "reps": 5,
        "weight": 225,
        "superset_group": null,
        "notes": "High bar, ATG depth"
      },
      {
        "exercise": "Romanian Deadlift",
        "sets": 3,
        "reps": 10,
        "weight": 185,
        "superset_group": null,
        "notes": "Feel the hamstring stretch"
      },
      {
        "exercise": "Leg Press",
        "sets": 4,
        "reps": 12,
        "weight": 315,
        "superset_group": null,
        "notes": "Full ROM, control the descent"
      },
      {
        "exercise": "Leg Curls",
        "sets": 3,
        "reps": 12,
        "weight": 90,
        "superset_group": "C",
        "notes": "Lying or seated"
      },
      {
        "exercise": "Calf Raises",
        "sets": 4,
        "reps": 15,
        "weight": 135,
        "superset_group": "C",
        "notes": "Standing, full stretch and contraction"
      }
    ],
    "thursday": [
      {
        "exercise": "Incline Bench Press",
        "sets": 4,
        "reps": 8,
        "weight": 155,
        "superset_group": null,
        "notes": "Barbell, 30-degree angle"
      },
      {
        "exercise": "Dumbbell Flyes",
        "sets": 3,
        "reps": 12,
        "weight": 35,
        "superset_group": null,
        "notes": "Slight bend in elbows"
      },
      {
        "exercise": "Arnold Press",
        "sets": 3,
        "reps": 10,
        "weight": 50,
        "superset_group": null,
        "notes": "Dumbbells, rotate palms"
      },
      {
        "exercise": "Cable Lateral Raises",
        "sets": 3,
        "reps": 15,
        "weight": 15,
        "superset_group": "A",
        "notes": "Single arm, constant tension"
      },
      {
        "exercise": "Overhead Tricep Extension",
        "sets": 3,
        "reps": 12,
        "weight": 55,
        "superset_group": "A",
        "notes": "Dumbbell or cable"
      }
    ],
    "friday": [
      {
        "exercise": "Weighted Pull-ups",
        "sets": 4,
        "reps": 6,
        "weight": 25,
        "superset_group": null,
        "notes": "Belt or vest, controlled tempo"
      },
      {
        "exercise": "T-Bar Rows",
        "sets": 4,
        "reps": 10,
        "weight": 115,
        "superset_group": null,
        "notes": "Chest supported if available"
      },
      {
        "exercise": "Lat Pulldowns",
        "sets": 3,
        "reps": 12,
        "weight": 140,
        "superset_group": null,
        "notes": "Wide grip, lean back slightly"
      },
      {
        "exercise": "Rear Delt Flyes",
        "sets": 3,
        "reps": 15,
        "weight": 20,
        "superset_group": "B",
        "notes": "Dumbbells, bend at hips"
      },
      {
        "exercise": "Barbell Curls",
        "sets": 3,
        "reps": 10,
        "weight": 75,
        "superset_group": "B",
        "notes": "EZ bar or straight bar"
      }
    ],
    "saturday": [
      {
        "exercise": "Front Squat",
        "sets": 4,
        "reps": 8,
        "weight": 165,
        "superset_group": null,
        "notes": "Cross-arm or clean grip"
      },
      {
        "exercise": "Bulgarian Split Squat",
        "sets": 3,
        "reps": 10,
        "weight": 50,
        "superset_group": null,
        "notes": "Each leg, dumbbells"
      },
      {
        "exercise": "Leg Extensions",
        "sets": 3,
        "reps": 15,
        "weight": 120,
        "superset_group": null,
        "notes": "Control the eccentric"
      },
      {
        "exercise": "Walking Lunges",
        "sets": 3,
        "reps": 12,
        "weight": 40,
        "superset_group": "C",
        "notes": "Each leg, dumbbells"
      },
      {
        "exercise": "Seated Calf Raises",
        "sets": 4,
        "reps": 20,
        "weight": 90,
        "superset_group": "C",
        "notes": "Pause at top"
      }
    ]
  }'::jsonb,
  true
);

-- =====================================================
-- 2. CREATE SAMPLE SESSIONS
-- =====================================================
-- Sample workout sessions from the past week

-- Monday - Push Day (3 days ago)
insert into sessions (id, workout_id, date, entries, notes)
values (
  '10000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  current_date - interval '3 days',
  '[
    {"exercise": "Bench Press", "set": 1, "reps": 8, "weight": 185},
    {"exercise": "Bench Press", "set": 2, "reps": 8, "weight": 185},
    {"exercise": "Bench Press", "set": 3, "reps": 7, "weight": 185},
    {"exercise": "Bench Press", "set": 4, "reps": 6, "weight": 185},
    {"exercise": "Incline Dumbbell Press", "set": 1, "reps": 10, "weight": 60},
    {"exercise": "Incline Dumbbell Press", "set": 2, "reps": 10, "weight": 60},
    {"exercise": "Incline Dumbbell Press", "set": 3, "reps": 9, "weight": 60},
    {"exercise": "Overhead Press", "set": 1, "reps": 8, "weight": 115},
    {"exercise": "Overhead Press", "set": 2, "reps": 8, "weight": 115},
    {"exercise": "Overhead Press", "set": 3, "reps": 7, "weight": 115},
    {"exercise": "Overhead Press", "set": 4, "reps": 6, "weight": 115},
    {"exercise": "Lateral Raises", "set": 1, "reps": 12, "weight": 25},
    {"exercise": "Lateral Raises", "set": 2, "reps": 12, "weight": 25},
    {"exercise": "Lateral Raises", "set": 3, "reps": 11, "weight": 25},
    {"exercise": "Tricep Pushdowns", "set": 1, "reps": 12, "weight": 60},
    {"exercise": "Tricep Pushdowns", "set": 2, "reps": 12, "weight": 60},
    {"exercise": "Tricep Pushdowns", "set": 3, "reps": 11, "weight": 60}
  ]'::jsonb,
  'Great session, felt strong on bench'
);

-- Tuesday - Pull Day (2 days ago)
insert into sessions (id, workout_id, date, entries, notes)
values (
  '10000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000001',
  current_date - interval '2 days',
  '[
    {"exercise": "Deadlift", "set": 1, "reps": 6, "weight": 275},
    {"exercise": "Deadlift", "set": 2, "reps": 6, "weight": 275},
    {"exercise": "Deadlift", "set": 3, "reps": 5, "weight": 275},
    {"exercise": "Deadlift", "set": 4, "reps": 5, "weight": 275},
    {"exercise": "Pull-ups", "set": 1, "reps": 8, "weight": 0},
    {"exercise": "Pull-ups", "set": 2, "reps": 7, "weight": 0},
    {"exercise": "Pull-ups", "set": 3, "reps": 6, "weight": 0},
    {"exercise": "Pull-ups", "set": 4, "reps": 6, "weight": 0},
    {"exercise": "Barbell Rows", "set": 1, "reps": 10, "weight": 155},
    {"exercise": "Barbell Rows", "set": 2, "reps": 10, "weight": 155},
    {"exercise": "Barbell Rows", "set": 3, "reps": 9, "weight": 155},
    {"exercise": "Barbell Rows", "set": 4, "reps": 9, "weight": 155},
    {"exercise": "Face Pulls", "set": 1, "reps": 15, "weight": 40},
    {"exercise": "Face Pulls", "set": 2, "reps": 15, "weight": 40},
    {"exercise": "Face Pulls", "set": 3, "reps": 15, "weight": 40},
    {"exercise": "Hammer Curls", "set": 1, "reps": 12, "weight": 35},
    {"exercise": "Hammer Curls", "set": 2, "reps": 12, "weight": 35},
    {"exercise": "Hammer Curls", "set": 3, "reps": 11, "weight": 35}
  ]'::jsonb,
  'Back pump was incredible'
);

-- Wednesday - Leg Day (yesterday)
insert into sessions (id, workout_id, date, entries, notes)
values (
  '10000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000001',
  current_date - interval '1 day',
  '[
    {"exercise": "Squat", "set": 1, "reps": 5, "weight": 225},
    {"exercise": "Squat", "set": 2, "reps": 5, "weight": 225},
    {"exercise": "Squat", "set": 3, "reps": 5, "weight": 225},
    {"exercise": "Squat", "set": 4, "reps": 5, "weight": 225},
    {"exercise": "Squat", "set": 5, "reps": 4, "weight": 225},
    {"exercise": "Romanian Deadlift", "set": 1, "reps": 10, "weight": 185},
    {"exercise": "Romanian Deadlift", "set": 2, "reps": 10, "weight": 185},
    {"exercise": "Romanian Deadlift", "set": 3, "reps": 9, "weight": 185},
    {"exercise": "Leg Press", "set": 1, "reps": 12, "weight": 315},
    {"exercise": "Leg Press", "set": 2, "reps": 12, "weight": 315},
    {"exercise": "Leg Press", "set": 3, "reps": 11, "weight": 315},
    {"exercise": "Leg Press", "set": 4, "reps": 10, "weight": 315},
    {"exercise": "Leg Curls", "set": 1, "reps": 12, "weight": 90},
    {"exercise": "Leg Curls", "set": 2, "reps": 12, "weight": 90},
    {"exercise": "Leg Curls", "set": 3, "reps": 11, "weight": 90},
    {"exercise": "Calf Raises", "set": 1, "reps": 15, "weight": 135},
    {"exercise": "Calf Raises", "set": 2, "reps": 15, "weight": 135},
    {"exercise": "Calf Raises", "set": 3, "reps": 14, "weight": 135},
    {"exercise": "Calf Raises", "set": 4, "reps": 14, "weight": 135}
  ]'::jsonb,
  'Legs are toast, great workout'
);

-- =====================================================
-- 3. CALCULATE HISTORY FOR SAMPLE SESSIONS
-- =====================================================
-- Run aggregation functions to populate history tables

-- Calculate exercise and workout history for each session date
select calc_all_history(current_date - interval '3 days');
select calc_all_history(current_date - interval '2 days');
select calc_all_history(current_date - interval '1 day');

-- =====================================================
-- 4. VERIFICATION QUERIES
-- =====================================================
-- Uncomment to verify seed data was created successfully

-- SELECT 'Workouts' as table_name, count(*) as row_count FROM workouts
-- UNION ALL
-- SELECT 'Sessions', count(*) FROM sessions
-- UNION ALL
-- SELECT 'Exercise History', count(*) FROM exercise_history
-- UNION ALL
-- SELECT 'Workout History', count(*) FROM workout_history;

-- -- Show active workout
-- SELECT id, name, description, is_active FROM workouts WHERE is_active = true;

-- -- Show recent sessions
-- SELECT id, date, jsonb_array_length(entries) as num_sets FROM sessions ORDER BY date DESC;

-- -- Show workout history
-- SELECT * FROM workout_history ORDER BY date DESC;
