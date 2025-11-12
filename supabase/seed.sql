-- =====================================================
-- Workout Tracker GPT v1.0 - Seed Data
-- =====================================================
-- Sample data for testing and demonstration
-- Creates a Push/Pull/Legs workout plan with sample sessions
-- =====================================================

-- Clear existing data (for development/testing)
truncate table workout_history cascade;
truncate table exercise_history cascade;
truncate table sessions_flat cascade;
truncate table workouts_flat cascade;
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
-- 2. CREATE SAMPLE SESSIONS (FLAT TABLE VERSION)
-- =====================================================
-- Sample workout sessions from the past week using sessions_flat
-- Note: Seed data uses the new flat table structure

-- TODO: Rewrite seed data to use sessions_flat table
-- For now, the seed is simple and only creates the workout plan in workouts table
-- Sessions can be added via the log_set and log_multiple_sets RPC functions

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
