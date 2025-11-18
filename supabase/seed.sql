-- =====================================================
-- Workout Tracker GPT v1.0 - Seed Data
-- =====================================================
-- Sample data for testing and demonstration
-- Creates a Push/Pull/Legs workout plan with the flat table structure
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
-- Uses direct inserts into workouts table

insert into workouts (workout_name, workout_description, workout_is_active, day_name, exercise_order, exercise_name, sets, reps, weight, exercise_notes)
values
  -- Monday: Push (Chest, Shoulders, Triceps)
  ('Push/Pull/Legs v1', 'Classic PPL split focusing on progressive overload', true, 'monday', 1, 'Bench Press', 4, 8, 185, 'Barbell, touch chest each rep'),
  ('Push/Pull/Legs v1', 'Classic PPL split focusing on progressive overload', true, 'monday', 2, 'Incline Dumbbell Press', 3, 10, 60, '45-degree angle'),
  ('Push/Pull/Legs v1', 'Classic PPL split focusing on progressive overload', true, 'monday', 3, 'Overhead Press', 4, 8, 115, 'Strict form, no leg drive'),
  ('Push/Pull/Legs v1', 'Classic PPL split focusing on progressive overload', true, 'monday', 4, 'Lateral Raises', 3, 12, 25, 'Dumbbells, control the eccentric'),
  ('Push/Pull/Legs v1', 'Classic PPL split focusing on progressive overload', true, 'monday', 5, 'Tricep Pushdowns', 3, 12, 60, 'Rope attachment'),

  -- Tuesday: Pull (Back, Biceps)
  ('Push/Pull/Legs v1', 'Classic PPL split focusing on progressive overload', true, 'tuesday', 1, 'Deadlift', 4, 6, 275, 'Conventional stance, focus on form'),
  ('Push/Pull/Legs v1', 'Classic PPL split focusing on progressive overload', true, 'tuesday', 2, 'Pull-ups', 4, 8, 0, 'Bodyweight, full ROM'),
  ('Push/Pull/Legs v1', 'Classic PPL split focusing on progressive overload', true, 'tuesday', 3, 'Barbell Rows', 4, 10, 155, 'Pendlay style, explosive pull'),
  ('Push/Pull/Legs v1', 'Classic PPL split focusing on progressive overload', true, 'tuesday', 4, 'Face Pulls', 3, 15, 40, 'Rope attachment, high cable'),
  ('Push/Pull/Legs v1', 'Classic PPL split focusing on progressive overload', true, 'tuesday', 5, 'Hammer Curls', 3, 12, 35, 'Dumbbells, alternating arms'),

  -- Wednesday: Legs (Quads, Hamstrings, Calves)
  ('Push/Pull/Legs v1', 'Classic PPL split focusing on progressive overload', true, 'wednesday', 1, 'Squat', 5, 5, 225, 'High bar, ATG depth'),
  ('Push/Pull/Legs v1', 'Classic PPL split focusing on progressive overload', true, 'wednesday', 2, 'Romanian Deadlift', 3, 10, 185, 'Feel the hamstring stretch'),
  ('Push/Pull/Legs v1', 'Classic PPL split focusing on progressive overload', true, 'wednesday', 3, 'Leg Press', 4, 12, 315, 'Full ROM, control the descent'),
  ('Push/Pull/Legs v1', 'Classic PPL split focusing on progressive overload', true, 'wednesday', 4, 'Leg Curls', 3, 12, 90, 'Lying or seated'),
  ('Push/Pull/Legs v1', 'Classic PPL split focusing on progressive overload', true, 'wednesday', 5, 'Calf Raises', 4, 15, 135, 'Standing, full stretch and contraction'),

  -- Thursday: Push (Chest, Shoulders, Triceps)
  ('Push/Pull/Legs v1', 'Classic PPL split focusing on progressive overload', true, 'thursday', 1, 'Incline Bench Press', 4, 8, 155, 'Barbell, 30-degree angle'),
  ('Push/Pull/Legs v1', 'Classic PPL split focusing on progressive overload', true, 'thursday', 2, 'Dumbbell Flyes', 3, 12, 35, 'Slight bend in elbows'),
  ('Push/Pull/Legs v1', 'Classic PPL split focusing on progressive overload', true, 'thursday', 3, 'Arnold Press', 3, 10, 50, 'Dumbbells, rotate palms'),
  ('Push/Pull/Legs v1', 'Classic PPL split focusing on progressive overload', true, 'thursday', 4, 'Cable Lateral Raises', 3, 15, 15, 'Single arm, constant tension'),
  ('Push/Pull/Legs v1', 'Classic PPL split focusing on progressive overload', true, 'thursday', 5, 'Overhead Tricep Extension', 3, 12, 55, 'Dumbbell or cable'),

  -- Friday: Pull (Back, Biceps)
  ('Push/Pull/Legs v1', 'Classic PPL split focusing on progressive overload', true, 'friday', 1, 'Weighted Pull-ups', 4, 6, 25, 'Belt or vest, controlled tempo'),
  ('Push/Pull/Legs v1', 'Classic PPL split focusing on progressive overload', true, 'friday', 2, 'T-Bar Rows', 4, 10, 115, 'Chest supported if available'),
  ('Push/Pull/Legs v1', 'Classic PPL split focusing on progressive overload', true, 'friday', 3, 'Lat Pulldowns', 3, 12, 140, 'Wide grip, lean back slightly'),
  ('Push/Pull/Legs v1', 'Classic PPL split focusing on progressive overload', true, 'friday', 4, 'Rear Delt Flyes', 3, 15, 20, 'Dumbbells, bend at hips'),
  ('Push/Pull/Legs v1', 'Classic PPL split focusing on progressive overload', true, 'friday', 5, 'Barbell Curls', 3, 10, 75, 'EZ bar or straight bar'),

  -- Saturday: Legs (Quads, Hamstrings, Calves)
  ('Push/Pull/Legs v1', 'Classic PPL split focusing on progressive overload', true, 'saturday', 1, 'Front Squat', 4, 8, 165, 'Cross-arm or clean grip'),
  ('Push/Pull/Legs v1', 'Classic PPL split focusing on progressive overload', true, 'saturday', 2, 'Bulgarian Split Squat', 3, 10, 50, 'Each leg, dumbbells'),
  ('Push/Pull/Legs v1', 'Classic PPL split focusing on progressive overload', true, 'saturday', 3, 'Leg Extensions', 3, 15, 120, 'Control the eccentric'),
  ('Push/Pull/Legs v1', 'Classic PPL split focusing on progressive overload', true, 'saturday', 4, 'Walking Lunges', 3, 12, 40, 'Each leg, dumbbells'),
  ('Push/Pull/Legs v1', 'Classic PPL split focusing on progressive overload', true, 'saturday', 5, 'Seated Calf Raises', 4, 20, 90, 'Pause at top');

-- =====================================================
-- 2. VERIFICATION QUERIES
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
-- SELECT distinct workout_name, workout_description, day_name FROM workouts WHERE workout_is_active = true ORDER BY day_name;

-- -- Show Monday exercises
-- SELECT exercise_order, exercise_name, sets, reps, weight FROM workouts WHERE workout_name = 'Push/Pull/Legs v1' AND day_name = 'monday' ORDER BY exercise_order;
