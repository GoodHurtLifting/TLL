import 'package:sqflite/sqflite.dart';

import '../db/db_service.dart';
import '../db/table_names.dart';

class WorkoutCompletionService {
  WorkoutCompletionService._();

  static final WorkoutCompletionService instance =
  WorkoutCompletionService._();

  Future<void> startWorkout({
    required int workoutInstanceId,
  }) async {
    final db = await DbService.instance.database;

    await db.transaction((txn) async {
      final workout = await _getWorkoutInstanceById(txn, workoutInstanceId);
      final startedAt = workout['started_at'] as String?;
      final nowIso  = DateTime.now().toIso8601String();

      await txn.update(
        TableNames.workoutInstances,
        {
          'started_at': startedAt ?? nowIso,
          'status': 'active',
          'updated_at': nowIso,
        },
        where: 'id = ?',
        whereArgs: [workoutInstanceId],
      );

      await _ensureBlockMarkedActive(
        txn,
        workoutInstanceId: workoutInstanceId,
        nowIso: nowIso ,
      );
    });
  }

  Future<void> finishWorkout({
    required int workoutInstanceId,
  }) async {
    final db = await DbService.instance.database;

    await db.transaction((txn) async {
      final nowIso = DateTime.now().toIso8601String();
      final workout = await _getWorkoutInstanceById(txn, workoutInstanceId);
      final startedAt = workout['started_at'] as String?;

      await txn.update(
        TableNames.workoutInstances,
        {
          'started_at': startedAt ?? nowIso ,
          'completed_at': nowIso ,
          'status': 'completed',
          'updated_at': nowIso ,
        },
        where: 'id = ?',
        whereArgs: [workoutInstanceId],
      );

      await _recalculateBlockTotals(
        txn,
        workoutInstanceId: workoutInstanceId,
      );

      await _updateBlockCompletionStatus(
        txn,
        workoutInstanceId: workoutInstanceId,
        nowIso: nowIso ,
      );
    });
  }

  Future<bool> isBlockCompletedForWorkout({
    required int workoutInstanceId,
  }) async {
    final db = await DbService.instance.database;

    final rows = await db.rawQuery(
      '''
      SELECT
        bt.completed_workout_count,
        bt.total_workout_count
      FROM ${TableNames.workoutInstances} wi
      INNER JOIN ${TableNames.blockTotals} bt
        ON bt.block_instance_id = wi.block_instance_id
      WHERE wi.id = ?
      LIMIT 1
      ''',
      [workoutInstanceId],
    );

    if (rows.isEmpty) {
      return false;
    }

    final completedWorkoutCount =
        (rows.first['completed_workout_count'] as int?) ?? 0;
    final totalWorkoutCount = (rows.first['total_workout_count'] as int?) ?? 0;

    return totalWorkoutCount > 0 &&
        completedWorkoutCount >= totalWorkoutCount;
  }

  Future<int> getBlockInstanceIdForWorkout({
    required int workoutInstanceId,
  }) async {
    final db = await DbService.instance.database;

    final rows = await db.query(
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

  Future<void> reopenWorkout({
    required int workoutInstanceId,
  }) async {
    final db = await DbService.instance.database;

    await db.transaction((txn) async {
      final nowIso  = DateTime.now().toIso8601String();

      await txn.update(
        TableNames.workoutInstances,
        {
          'completed_at': null,
          'status': 'active',
          'updated_at': nowIso ,
        },
        where: 'id = ?',
        whereArgs: [workoutInstanceId],
      );

      await _recalculateBlockTotals(
        txn,
        workoutInstanceId: workoutInstanceId,
      );

      await _updateBlockToActive(
        txn,
        workoutInstanceId: workoutInstanceId,
        nowIso: nowIso ,
      );
    });
  }

  Future<Map<String, Object?>> _getWorkoutInstanceById(
      Transaction txn,
      int workoutInstanceId,
      ) async {
    final rows = await txn.query(
      TableNames.workoutInstances,
      where: 'id = ?',
      whereArgs: [workoutInstanceId],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw Exception('Missing workout_instance for id: $workoutInstanceId');
    }

    return rows.first;
  }

  Future<void> _ensureBlockMarkedActive(
      Transaction txn, {
        required int workoutInstanceId,
        required String nowIso,
      }) async {
    final blockInstanceId = await _getBlockInstanceIdForWorkout(txn, workoutInstanceId);

    final rows = await txn.query(
      TableNames.blockInstances,
      columns: ['started_at', 'status'],
      where: 'id = ?',
      whereArgs: [blockInstanceId],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw Exception('Missing block_instance for id: $blockInstanceId');
    }

    final block = rows.first;
    final startedAt = block['started_at'] as String?;

    await txn.update(
      TableNames.blockInstances,
      {
        'started_at': startedAt ?? nowIso,
        'status': 'active',
        'updated_at': nowIso,
      },
      where: 'id = ?',
      whereArgs: [blockInstanceId],
    );
  }

  Future<void> _updateBlockCompletionStatus(
      Transaction txn, {
        required int workoutInstanceId,
        required String nowIso,
      }) async {
    final blockInstanceId = await _getBlockInstanceIdForWorkout(txn, workoutInstanceId);

    final rows = await txn.query(
      TableNames.blockTotals,
      where: 'block_instance_id = ?',
      whereArgs: [blockInstanceId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return;
    }

    final blockTotals = rows.first;
    final completedWorkoutCount =
        (blockTotals['completed_workout_count'] as int?) ?? 0;
    final totalWorkoutCount = (blockTotals['total_workout_count'] as int?) ?? 0;

    final isComplete =
        totalWorkoutCount > 0 && completedWorkoutCount >= totalWorkoutCount;

    await txn.update(
      TableNames.blockInstances,
      {
        'status': isComplete ? 'completed' : 'active',
        'completed_at': isComplete ? nowIso : null,
        'updated_at': nowIso,
      },
      where: 'id = ?',
      whereArgs: [blockInstanceId],
    );
  }

  Future<void> _updateBlockToActive(
      Transaction txn, {
        required int workoutInstanceId,
        required String nowIso,
      }) async {
    final blockInstanceId = await _getBlockInstanceIdForWorkout(txn, workoutInstanceId);

    await txn.update(
      TableNames.blockInstances,
      {
        'status': 'active',
        'completed_at': null,
        'updated_at': nowIso,
      },
      where: 'id = ?',
      whereArgs: [blockInstanceId],
    );
  }

  Future<void> _recalculateBlockTotals(
      Transaction txn, {
        required int workoutInstanceId,
      }) async {
    final blockInstanceId = await _getBlockInstanceIdForWorkout(txn, workoutInstanceId);

    final nowIso = DateTime.now().toIso8601String();

    final workoutInstances = await txn.query(
      TableNames.workoutInstances,
      columns: ['id', 'workout_template_id', 'completed_at'],
      where: 'block_instance_id = ?',
      whereArgs: [blockInstanceId],
      orderBy: 'workout_slot_index ASC',
    );

    double totalWorkload = 0.0;
    int completedWorkoutCount = 0;
    final Map<int, double> bestScoreByWorkoutTemplate = {};
    final Set<String> uniqueTrainingDays = {};

    for (final workout in workoutInstances) {
      final currentWorkoutInstanceId = workout['id'] as int;
      final workoutTemplateId = workout['workout_template_id'] as int;
      final completedAt = workout['completed_at'] as String?;

      if (completedAt != null && completedAt.isNotEmpty) {
        completedWorkoutCount += 1;
        uniqueTrainingDays.add(completedAt.substring(0, 10));
      }

      final workoutTotalRows = await txn.query(
        TableNames.workoutTotals,
        where: 'workout_instance_id = ?',
        whereArgs: [currentWorkoutInstanceId],
        limit: 1,
      );

      if (workoutTotalRows.isEmpty) {
        continue;
      }

      final row = workoutTotalRows.first;
      final workoutWorkload =
      ((row['total_workload'] as num?) ?? 0).toDouble();
      final workoutScore = ((row['workout_score'] as num?) ?? 0).toDouble();

      totalWorkload += workoutWorkload;

      final existingBest = bestScoreByWorkoutTemplate[workoutTemplateId];
      if (existingBest == null || workoutScore > existingBest) {
        bestScoreByWorkoutTemplate[workoutTemplateId] = workoutScore;
      }
    }

    final totalWorkoutCount = workoutInstances.length;
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
        'updated_at': nowIso,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> _getBlockInstanceIdForWorkout(
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