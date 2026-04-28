import 'seed_models.dart';

class LiftCatalogSeed {
  static const muscleGroups = [
    SeedMuscleGroup(muscleKey: 'chest', name: 'Chest', sortOrder: 1),
    SeedMuscleGroup(muscleKey: 'front_delts', name: 'Front Delts', sortOrder: 2),
    SeedMuscleGroup(muscleKey: 'triceps', name: 'Triceps', sortOrder: 3),
    SeedMuscleGroup(muscleKey: 'quads', name: 'Quads', sortOrder: 4),
    SeedMuscleGroup(muscleKey: 'glutes', name: 'Glutes', sortOrder: 5),
    SeedMuscleGroup(muscleKey: 'hamstrings', name: 'Hamstrings', sortOrder: 6),
  ];

  static const lifts = [
    SeedLift(
      liftKey: 'squat',
      name: 'Squats',
      scoreType: 'multiplier',
      equipment: 'barbell',
      muscleGroups: [
        SeedLiftMuscleGroup(muscleKey: 'quads', role: 'primary', sortOrder: 1),
        SeedLiftMuscleGroup(muscleKey: 'glutes', role: 'secondary', sortOrder: 2),
        SeedLiftMuscleGroup(muscleKey: 'hamstrings', role: 'secondary', sortOrder: 3),
      ],
    ),
    SeedLift(
      liftKey: 'bench_press',
      name: 'Bench Press',
      scoreType: 'multiplier',
      equipment: 'barbell',
      muscleGroups: [
        SeedLiftMuscleGroup(muscleKey: 'chest', role: 'primary', sortOrder: 1),
        SeedLiftMuscleGroup(muscleKey: 'front_delts', role: 'secondary', sortOrder: 2),
        SeedLiftMuscleGroup(muscleKey: 'triceps', role: 'secondary', sortOrder: 3),
      ],
    ),
    SeedLift(
      liftKey: 'deadlift',
      name: 'Deadlift',
      scoreType: 'multiplier',
      equipment: 'barbell',
      muscleGroups: [
        SeedLiftMuscleGroup(muscleKey: 'glutes', role: 'primary', sortOrder: 1),
        SeedLiftMuscleGroup(muscleKey: 'hamstrings', role: 'secondary', sortOrder: 2),
      ],
    ),
    SeedLift(
      liftKey: 'push_up',
      name: 'Push-Ups',
      scoreType: 'bodyweight',
      equipment: 'bodyweight',
      inputMode: 'standard',
      muscleGroups: [
        SeedLiftMuscleGroup(muscleKey: 'chest', role: 'primary', sortOrder: 1),
        SeedLiftMuscleGroup(muscleKey: 'front_delts', role: 'secondary', sortOrder: 2),
        SeedLiftMuscleGroup(muscleKey: 'triceps', role: 'secondary', sortOrder: 3),
      ],
    ),
  ];
}
