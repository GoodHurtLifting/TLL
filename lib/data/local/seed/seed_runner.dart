import 'package:sqflite/sqflite.dart';

import '../db/db_service.dart';
import '../db/table_names.dart';
import 'block_seed.dart';
import 'lift_catalog_seed.dart';
import 'seed_validator.dart';

class SeedRunner {
  static Future<void> seedAll() async {
    SeedValidator.validateAll();

    final db = await DbService.instance.database;

    await db.transaction((txn) async {
      await _seedMuscleGroups(txn);
      await _seedLiftCatalog(txn);
      await _seedLiftCatalogMuscleGroups(txn);
      await _seedBlockTemplates(txn);
      await _seedWorkoutTemplates(txn);
      await _seedWorkoutTemplateLifts(txn);
    });
  }

  static Future<void> _seedMuscleGroups(Transaction txn) async {
    for (final muscle in LiftCatalogSeed.muscleGroups) {
      await txn.insert(
        TableNames.muscleGroups,
        {
          'muscle_key': muscle.muscleKey,
          'name': muscle.name,
          'sort_order': muscle.sortOrder,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  static Future<void> _seedLiftCatalog(Transaction txn) async {
    for (final lift in LiftCatalogSeed.lifts) {
      await txn.insert(
        TableNames.liftCatalog,
        {
          'lift_key': lift.liftKey,
          'name': lift.name,
          'score_type': lift.scoreType,
          'equipment': lift.equipment,
          'input_mode': lift.inputMode,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  static Future<void> _seedLiftCatalogMuscleGroups(Transaction txn) async {
    for (final lift in LiftCatalogSeed.lifts) {
      final liftCatalogId = await _getLiftCatalogIdByKey(txn, lift.liftKey);

      for (final muscle in lift.muscleGroups) {
        final muscleGroupId = await _getMuscleGroupIdByKey(txn, muscle.muscleKey);

        await txn.insert(
          TableNames.liftCatalogMuscleGroups,
          {
            'lift_catalog_id': liftCatalogId,
            'muscle_group_id': muscleGroupId,
            'role': muscle.role,
            'sort_order': muscle.sortOrder,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
  }

  static Future<void> _seedBlockTemplates(Transaction txn) async {
    for (final block in BlockSeed.blocks) {
      await txn.insert(
        TableNames.blockTemplates,
        {
          'block_key': block.blockKey,
          'title': block.title,
          'description': block.description,
          'category': block.category,
          'difficulty': block.difficulty,
          'num_weeks': block.numWeeks,
          'schedule_type': block.scheduleType,
          'workouts_per_week': block.workoutsPerWeek,
          'total_workout_slots': block.totalWorkoutSlots,
          'is_custom': 0,
          'owner_user_id': null,
          'is_active': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  static Future<void> _seedWorkoutTemplates(Transaction txn) async {
    for (final block in BlockSeed.blocks) {
      final blockTemplateId = await _getBlockTemplateIdByKey(txn, block.blockKey);

      for (final workout in block.workouts) {
        await txn.insert(
          TableNames.workoutTemplates,
          {
            'workout_key': workout.workoutKey,
            'block_template_id': blockTemplateId,
            'title': workout.title,
            'workout_type': workout.workoutType,
            'sequence_index': workout.sequenceIndex,
            'is_active': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
  }

  static Future<void> _seedWorkoutTemplateLifts(Transaction txn) async {
    for (final block in BlockSeed.blocks) {
      for (final workout in block.workouts) {
        final workoutTemplateId =
        await _getWorkoutTemplateIdByKey(txn, workout.workoutKey);

        for (final lift in workout.lifts) {
          final liftCatalogId = await _getLiftCatalogIdByKey(txn, lift.liftKey);

          await txn.insert(
            TableNames.workoutTemplateLifts,
            {
              'workout_template_id': workoutTemplateId,
              'lift_catalog_id': liftCatalogId,
              'sequence_index': lift.sequenceIndex,
              'rep_scheme': lift.repScheme,
              'lift_info': lift.liftInfo,
              'score_type': lift.scoreType,
              'score_multiplier': lift.scoreMultiplier,
              'score_multiplier_mode': lift.scoreMultiplierMode,
              'input_mode': lift.inputMode,
              'reference_source': lift.referenceSource,
              'reference_lift_key': lift.referenceLiftKey,
              'percent_value': lift.percentValue,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
    }
  }

  static Future<int> _getBlockTemplateIdByKey(
      Transaction txn,
      String blockKey,
      ) async {
    final rows = await txn.query(
      TableNames.blockTemplates,
      columns: ['id'],
      where: 'block_key = ?',
      whereArgs: [blockKey],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw Exception('Missing block_template for key: $blockKey');
    }

    return rows.first['id'] as int;
  }

  static Future<int> _getWorkoutTemplateIdByKey(
      Transaction txn,
      String workoutKey,
      ) async {
    final rows = await txn.query(
      TableNames.workoutTemplates,
      columns: ['id'],
      where: 'workout_key = ?',
      whereArgs: [workoutKey],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw Exception('Missing workout_template for key: $workoutKey');
    }

    return rows.first['id'] as int;
  }

  static Future<int> _getLiftCatalogIdByKey(
      Transaction txn,
      String liftKey,
      ) async {
    final rows = await txn.query(
      TableNames.liftCatalog,
      columns: ['id'],
      where: 'lift_key = ?',
      whereArgs: [liftKey],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw Exception('Missing lift_catalog row for key: $liftKey');
    }

    return rows.first['id'] as int;
  }

  static Future<int> _getMuscleGroupIdByKey(
      Transaction txn,
      String muscleKey,
      ) async {
    final rows = await txn.query(
      TableNames.muscleGroups,
      columns: ['id'],
      where: 'muscle_key = ?',
      whereArgs: [muscleKey],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw Exception('Missing muscle_group row for key: $muscleKey');
    }

    return rows.first['id'] as int;
  }
}
