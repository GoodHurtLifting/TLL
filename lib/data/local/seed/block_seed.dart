import 'seed_models.dart';

class BlockSeed {
  static const blocks = [
    SeedBlock(
      blockKey: 'starter_block',
      title: 'Starter Block',
      description: 'Temporary seed block for DB validation.',
      category: 'Powerbuilding',
      difficulty: 'Beginner',
      numWeeks: 4,
      scheduleType: 'three_day_standard',
      workoutsPerWeek: 3,
      totalWorkoutSlots: 12,
      workouts: [
        SeedWorkout(
          workoutKey: 'starter_push_a',
          title: 'Push A',
          workoutType: 'Push',
          sequenceIndex: 0,
          lifts: [
            SeedWorkoutLift(
              liftKey: 'bench_press',
              sequenceIndex: 0,
              repScheme: '4x6',
            ),
            SeedWorkoutLift(
              liftKey: 'push_up',
              sequenceIndex: 1,
              repScheme: '3x12',
            ),
          ],
        ),
      ],
    ),
  ];
}