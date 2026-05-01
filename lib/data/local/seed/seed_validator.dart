import 'block_seed.dart';
import 'lift_catalog_seed.dart';
import 'seed_models.dart';

class SeedValidator {
  static final RegExp _snakeCasePattern = RegExp(r'^[a-z]+(?:_[a-z0-9]+)*$');

  static const Set<String> _allowedScoreTypes = {
    'multiplier',
    'bodyweight',
  };

  static const Set<String> _allowedInputModes = {
    'standard',
    'per_side',
  };

  static const Set<String> _allowedEquipment = {
    'barbell',
    'dumbbell',
    'kettlebell',
    'machine',
    'cable_machine',
    'captains_chair',
    'bodyweight',
    'floor',
    'band',
    'smith_machine',
    'landmine',
    'rings',
    'plate',
    'trap_bar',
    'pull-up_bar',
    'other',
  };

  static const Set<String> _allowedMuscleRoles = {
    'primary',
    'secondary',
  };

  static const Set<String> _allowedMultiplierModes = {
    'fixed',
    'predictive',
    'manual',
  };

  static void validateAll() {
    final errors = <String>[];

    final liftByKey = _validateLiftCatalog(errors);
    _validateBlockTemplates(errors, liftByKey);

    if (errors.isNotEmpty) {
      throw Exception('Seed validation failed:\n- ${errors.join('\n- ')}');
    }
  }

  static Map<String, SeedLift> _validateLiftCatalog(List<String> errors) {
    final muscleKeys = <String>{};

    for (final muscle in LiftCatalogSeed.muscleGroups) {
      if (!muscleKeys.add(muscle.muscleKey)) {
        errors.add('Duplicate muscle group key: ${muscle.muscleKey}');
      }
      if (!_isLowerSnakeCase(muscle.muscleKey)) {
        errors.add('Muscle group key must be lowercase snake_case: ${muscle.muscleKey}');
      }
      if (muscle.name.trim().isEmpty) {
        errors.add('Muscle group ${muscle.muscleKey} has empty name');
      }
    }

    final liftByKey = <String, SeedLift>{};

    for (final lift in LiftCatalogSeed.lifts) {
      if (liftByKey.containsKey(lift.liftKey)) {
        errors.add('Duplicate liftKey: ${lift.liftKey}');
      } else {
        liftByKey[lift.liftKey] = lift;
      }

      if (!_isLowerSnakeCase(lift.liftKey)) {
        errors.add('liftKey must be lowercase snake_case: ${lift.liftKey}');
      }
      if (lift.name.trim().isEmpty) {
        errors.add('Lift ${lift.liftKey} has empty name');
      }
      if (!_allowedScoreTypes.contains(lift.scoreType)) {
        errors.add('Lift ${lift.liftKey} has invalid scoreType: ${lift.scoreType}');
      }
      if (!_allowedInputModes.contains(lift.inputMode)) {
        errors.add('Lift ${lift.liftKey} has invalid inputMode: ${lift.inputMode}');
      }
      if (lift.equipment != null && !_allowedEquipment.contains(lift.equipment)) {
        errors.add(
          'Lift ${lift.liftKey} has unsupported equipment: ${lift.equipment}',
        );
      }

      for (final muscle in lift.muscleGroups) {
        if (!muscleKeys.contains(muscle.muscleKey)) {
          errors.add(
            'Lift ${lift.liftKey} references missing muscle group: ${muscle.muscleKey}',
          );
        }
        if (!_allowedMuscleRoles.contains(muscle.role)) {
          errors.add(
            'Lift ${lift.liftKey} muscle ${muscle.muscleKey} has invalid role: ${muscle.role}',
          );
        }
      }
    }

    return liftByKey;
  }

  static void _validateBlockTemplates(
    List<String> errors,
    Map<String, SeedLift> liftByKey,
  ) {
    final blockKeys = <String>{};
    final workoutKeys = <String>{};

    for (final block in BlockSeed.blocks) {
      if (!blockKeys.add(block.blockKey)) {
        errors.add('Duplicate blockKey: ${block.blockKey}');
      }
      if (!_isLowerSnakeCase(block.blockKey)) {
        errors.add('blockKey must be lowercase snake_case: ${block.blockKey}');
      }
      if (block.title.trim().isEmpty) {
        errors.add('Block ${block.blockKey} has empty title');
      }
      if (block.workouts.isEmpty) {
        errors.add('Block ${block.blockKey} must have at least one workout');
      }

      for (final workout in block.workouts) {
        if (!workoutKeys.add(workout.workoutKey)) {
          errors.add('Duplicate workoutKey: ${workout.workoutKey}');
        }
        if (!_isLowerSnakeCase(workout.workoutKey)) {
          errors.add('workoutKey must be lowercase snake_case: ${workout.workoutKey}');
        }
        if (workout.lifts.isEmpty) {
          errors.add('Workout ${workout.workoutKey} must have at least one lift');
        }

        for (final lift in workout.lifts) {
          final catalogLift = liftByKey[lift.liftKey];
          if (catalogLift == null) {
            errors.add(
              'Workout ${workout.workoutKey} references missing liftKey: ${lift.liftKey}',
            );
          }

          if (lift.repScheme.trim().isEmpty) {
            errors.add(
              'Workout ${workout.workoutKey} lift ${lift.liftKey} has empty repScheme',
            );
          }

          if (lift.inputMode != null && !_allowedInputModes.contains(lift.inputMode)) {
            errors.add(
              'Workout ${workout.workoutKey} lift ${lift.liftKey} has invalid inputMode: ${lift.inputMode}',
            );
          }

          if (lift.scoreType != null && !_allowedScoreTypes.contains(lift.scoreType)) {
            errors.add(
              'Workout ${workout.workoutKey} lift ${lift.liftKey} has invalid scoreType: ${lift.scoreType}',
            );
          }

          final resolvedScoreType = lift.scoreType ?? catalogLift?.scoreType;

          if (resolvedScoreType == 'multiplier') {
            if (lift.scoreMultiplier == null) {
              errors.add(
                'Workout ${workout.workoutKey} lift ${lift.liftKey} is multiplier but has no scoreMultiplier',
              );
            }
            if (lift.scoreMultiplierMode == null) {
              errors.add(
                'Workout ${workout.workoutKey} lift ${lift.liftKey} is multiplier but has no scoreMultiplierMode',
              );
            } else if (!_allowedMultiplierModes.contains(lift.scoreMultiplierMode)) {
              errors.add(
                'Workout ${workout.workoutKey} lift ${lift.liftKey} has invalid scoreMultiplierMode: ${lift.scoreMultiplierMode}',
              );
            }
          }
        }
      }
    }
  }

  static bool _isLowerSnakeCase(String value) {
    return _snakeCasePattern.hasMatch(value);
  }
}
