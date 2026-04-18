import 'package:sqflite/sqflite.dart';

import '../db/db_service.dart';
import '../db/table_names.dart';

class BlockTotalsService {
  BlockTotalsService._();

  static final BlockTotalsService instance = BlockTotalsService._();

  Future<void> recalculateBlockTotals({
    required int blockInstanceId,
  }) async {
    final db = await DbService.instance.database;

    await db.transaction((txn) async {
      await _recalculateBlockTotalsInTransaction(
        txn,
        blockInstanceId: blockInstanceId,
      );
    });
  }

  Future<void> recalculateBlockTotalsForWorkout({
    required int workoutInstanceId,
  }) async {
    final db = await DbService.instance.database;

    await db.transaction((txn) async {
      final blockInstanceId = await _getBlockInstanceIdForWorkoutInstance(
        txn,
        workoutInstanceId,
      );

      await _recalculateBlockTotalsInTransaction(
        txn,
        blockInstanceId: blockInstanceId,
      );
    });
  }

  Future<void> _recalculateBlockTotalsInTransaction(
      Transaction txn, {
        required int blockInstanceId,
      }) async {
    final workoutInstances = await txn.query(
      TableNames.workoutInstances,
      columns: [
        'id',
        'workout_template_id',
        'completed_at',
      ],
      where: 'block_instance_id = ?',
      whereArgs: [blockInstanceId],
      orderBy: 'workout_slot_index ASC',
    );

    final totalWorkoutCount = workoutInstances.length;

    if (totalWorkoutCount == 0) {
      await txn.insert(
        TableNames.blockTotals,
        {
          'block_instance_id': blockInstanceId,
          'total_workload': 0.0,
          'block_score': 0.0,
          'completed_workout_count': 0,
          'total_workout_count': 0,
          'training_days': 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return;
    }

    double totalWorkload = 0.0;
    int completedWorkoutCount = 0;
    final Map<int, double> bestScoreByWorkoutTemplate = {};
    final Set<String> uniqueTrainingDays = {};

    for (final workout in workoutInstances) {
      final workoutInstanceId = workout['id'] as int;
      final workoutTemplateId = workout['workout_template_id'] as int;
      final completedAt = workout['completed_at'] as String?;

      if (completedAt != null && completedAt.isNotEmpty) {
        completedWorkoutCount += 1;
        uniqueTrainingDays.add(completedAt.substring(0, 10));
      }

      final workoutTotalsRows = await txn.query(
        TableNames.workoutTotals,
        where: 'workout_instance_id = ?',
        whereArgs: [workoutInstanceId],
        limit: 1,
      );

      if (workoutTotalsRows.isEmpty) {
        continue;
      }

      final row = workoutTotalsRows.first;
      final workoutWorkload =
      ((row['total_workload'] as num?) ?? 0).toDouble();
      final workoutScore = ((row['workout_score'] as num?) ?? 0).toDouble();

      totalWorkload += workoutWorkload;

      final currentBest = bestScoreByWorkoutTemplate[workoutTemplateId];
      if (currentBest == null || workoutScore > currentBest) {
        bestScoreByWorkoutTemplate[workoutTemplateId] = workoutScore;
      }
    }

    final bestScores = bestScoreByWorkoutTemplate.values.toList();
    final blockScore = bestScores.isEmpty
        ? 0.0
        : bestScores.reduce((a, b) => a + b) / bestScores.length;

    await txn.insert(
      TableNames.blockTotals,
      {
        'block_instance_id': blockInstanceId,
        'total_workload': totalWorkload,
        'block_score': blockScore,
        'completed_workout_count': completedWorkoutCount,
        'total_workout_count': totalWorkoutCount,
        'training_days': uniqueTrainingDays.length,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> _getBlockInstanceIdForWorkoutInstance(
      Transaction txn,
      int workoutInstanceId,
      ) async {
    final rows = await txn.query(
      TableNames.workoutInstances,
      columns: ['block_instance_id'],
      where: 'id = ?',
      whereArgs: [workoutInstanceId],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw Exception(
        'Missing block_instance_id for workout_instance_id: $workoutInstanceId',
      );
    }

    return rows.first['block_instance_id'] as int;
  }
}