class SeedMuscleGroup {
  final String muscleKey;
  final String name;
  final int sortOrder;

  const SeedMuscleGroup({
    required this.muscleKey,
    required this.name,
    this.sortOrder = 0,
  });
}

class SeedLiftMuscleGroup {
  final String muscleKey;
  final String role;
  final int sortOrder;

  const SeedLiftMuscleGroup({
    required this.muscleKey,
    required this.role,
    this.sortOrder = 0,
  });
}

class SeedLift {
  final String liftKey;
  final String name;
  final String scoreType;
  final double? scoreMultiplier;
  final String inputMode;
  final List<SeedLiftMuscleGroup> muscleGroups;

  const SeedLift({
    required this.liftKey,
    required this.name,
    required this.scoreType,
    this.scoreMultiplier,
    this.inputMode = 'standard',
    this.muscleGroups = const [],
  });
}

class SeedWorkoutLift {
  final String liftKey;
  final int sequenceIndex;
  final String repScheme;
  final String? liftInfoOverride;
  final String? scoreTypeOverride;
  final double? scoreMultiplierOverride;
  final String? inputModeOverride;
  final String? referenceSource;
  final String? referenceLiftKey;
  final double? percentValue;

  const SeedWorkoutLift({
    required this.liftKey,
    required this.sequenceIndex,
    required this.repScheme,
    this.liftInfoOverride,
    this.scoreTypeOverride,
    this.scoreMultiplierOverride,
    this.inputModeOverride,
    this.referenceSource,
    this.referenceLiftKey,
    this.percentValue,
  });
}

class SeedWorkout {
  final String workoutKey;
  final String title;
  final String? workoutType;
  final int sequenceIndex;
  final List<SeedWorkoutLift> lifts;

  const SeedWorkout({
    required this.workoutKey,
    required this.title,
    this.workoutType,
    required this.sequenceIndex,
    required this.lifts,
  });
}

class SeedBlock {
  final String blockKey;
  final String title;
  final String? description;
  final String category;
  final String? difficulty;
  final int numWeeks;
  final String scheduleType;
  final int? workoutsPerWeek;
  final int? totalWorkoutSlots;
  final List<SeedWorkout> workouts;

  const SeedBlock({
    required this.blockKey,
    required this.title,
    this.description,
    required this.category,
    this.difficulty,
    required this.numWeeks,
    required this.scheduleType,
    this.workoutsPerWeek,
    this.totalWorkoutSlots,
    required this.workouts,
  });
}