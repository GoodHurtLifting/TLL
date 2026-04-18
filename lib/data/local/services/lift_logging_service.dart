import 'package:sqflite/sqflite.dart';

import '../db/db_service.dart';
import '../db/table_names.dart';

class LiftLoggingService {
  LiftLoggingService._();

  static final LiftLoggingService instance = LiftLoggingService._();

  Future<void> saveSetEntry({
    required int liftInstanceId,
    required int setIndex,
    required int reps,
    required double weight,
  }) async {
    final db = await DbService.instance.database;

    await db.transaction((txn) async {
      final workoutInstanceId = await _getWorkoutInstanceIdForLiftInstance(
        txn,
        liftInstanceId,
      );

      await txn.insert(
        TableNames.liftLogs,
        {
          'lift_instance_id': liftInstanceId,
          'set_index': setIndex,
          'reps': reps,
          'weight': weight,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await _recalculateLiftTotals(
        txn,
        liftInstanceId: liftInstanceId,
      );

      await _recalculateWorkoutTotals(
        txn,
        workoutInstanceId: workoutInstanceId,
      );
    });
  }

  Future<void> deleteSetEntry({
    required int liftInstanceId,
    required int setIndex,
  }) async {
    final db = await DbService.instance.database;

    await db.transaction((txn) async {
      final workoutInstanceId = await _getWorkoutInstanceIdForLiftInstance(
        txn,
        liftInstanceId,
      );

      await txn.delete(
        TableNames.liftLogs,
        where: 'lift_instance_id = ? AND set_index = ?',
        whereArgs: [liftInstanceId, setIndex],
      );

      await _recalculateLiftTotals(
        txn,
        liftInstanceId: liftInstanceId,
      );

      await _recalculateWorkoutTotals(
        txn,
        workoutInstanceId: workoutInstanceId,
      );
    });
  }

  Future<void> _recalculateLiftTotals(
      Transaction txn, {
        required int liftInstanceId,
      }) async {
    final liftInstance = await _getLiftInstanceById(txn, liftInstanceId);
    final scoreType = liftInstance['score_type_snapshot'] as String;
    final inputMode =
        (liftInstance['input_mode_snapshot'] as String?) ?? 'standard';
    final scoreMultiplier =
    (liftInstance['score_multiplier_snapshot'] as num?)?.toDouble();

    final logs = await txn.query(
      TableNames.liftLogs,
      where: 'lift_instance_id = ?',
      whereArgs: [liftInstanceId],
      orderBy: 'set_index ASC',
    );

    var effectiveTotalReps = 0;
    var totalWorkload = 0.0;
    var weightSum = 0.0;

    for (final log in logs) {
      final reps = (log['reps'] as int?) ?? 0;
      final weight = ((log['weight'] as num?) ?? 0).toDouble();

      final effectiveReps = _getEffectiveReps(
        inputMode: inputMode,
        reps: reps,
      );

      final setWorkload = _getSetWorkload(
        inputMode: inputMode,
        reps: reps,
        weight: weight,
      );

      effectiveTotalReps += effectiveReps;
      totalWorkload += setWorkload;
      weightSum += weight;
    }

    final totalScore = _calculateLiftScore(
      scoreType: scoreType,
      effectiveTotalReps: effectiveTotalReps,
      weightSum: weightSum,
      scoreMultiplier: scoreMultiplier,
    );

    final now = DateTime.now().toIso8601String();

    await txn.insert(
      TableNames.liftTotals,
      {
        'lift_instance_id': liftInstanceId,
        'total_reps': effectiveTotalReps,
        'total_workload': totalWorkload,
        'total_score': totalScore,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _recalculateWorkoutTotals(
      Transaction txn, {
        required int workoutInstanceId,
      }) async {
    final workoutLifts = await txn.query(
      TableNames.liftInstances,
      columns: ['id'],
      where: 'workout_instance_id = ?',
      whereArgs: [workoutInstanceId],
      orderBy: 'sequence_index ASC',
    );

    final totalLiftCount = workoutLifts.length;

    if (totalLiftCount == 0) {
      await txn.insert(
        TableNames.workoutTotals,
        {
          'workout_instance_id': workoutInstanceId,
          'total_workload': 0.0,
          'workout_score': 0.0,
          'completed_lift_count': 0,
          'total_lift_count': 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return;
    }

    double totalWorkload = 0.0;
    double scoreSum = 0.0;
    int completedLiftCount = 0;

    for (final lift in workoutLifts) {
      final liftInstanceId = lift['id'] as int;

      final liftTotalRows = await txn.query(
        TableNames.liftTotals,
        where: 'lift_instance_id = ?',
        whereArgs: [liftInstanceId],
        limit: 1,
      );

      if (liftTotalRows.isEmpty) {
        continue;
      }

      final row = liftTotalRows.first;
      final liftWorkload = ((row['total_workload'] as num?) ?? 0).toDouble();
      final liftScore = ((row['total_score'] as num?) ?? 0).toDouble();
      final liftReps = (row['total_reps'] as int?) ?? 0;

      totalWorkload += liftWorkload;
      scoreSum += liftScore;

      if (liftReps > 0) {
        completedLiftCount += 1;
      }
    }

    final workoutScore = scoreSum / totalLiftCount;

    await txn.insert(
      TableNames.workoutTotals,
      {
        'workout_instance_id': workoutInstanceId,
        'total_workload': totalWorkload,
        'workout_score': workoutScore,
        'completed_lift_count': completedLiftCount,
        'total_lift_count': totalLiftCount,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    final workoutInstanceIdForBlockTotals = workoutInstanceId;
    await _recalculateBlockTotalsFromWorkout(
      txn,
      workoutInstanceId: workoutInstanceIdForBlockTotals,
    );
  }

  Future<void> _recalculateBlockTotalsFromWorkout(
      Transaction txn, {
        required int workoutInstanceId,
      }) async {
    final workoutRows = await txn.query(
      TableNames.workoutInstances,
      columns: ['block_instance_id'],
      where: 'id = ?',
      whereArgs: [workoutInstanceId],
      limit: 1,
    );

    if (workoutRows.isEmpty) {
      throw Exception(
        'Missing workout_instance for block totals refresh: $workoutInstanceId',
      );
    }

    final blockInstanceId = workoutRows.first['block_instance_id'] as int;

    double totalWorkload = 0.0;
    int completedWorkoutCount = 0;
    final Map<int, double> bestScoreByWorkoutTemplate = {};
    final Set<String> uniqueTrainingDays = {};

    final workoutInstances = await txn.query(
      TableNames.workoutInstances,
      columns: ['id', 'workout_template_id', 'completed_at'],
      where: 'block_instance_id = ?',
      whereArgs: [blockInstanceId],
      orderBy: 'workout_slot_index ASC',
    );

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
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  int _getEffectiveReps({
    required String inputMode,
    required int reps,
  }) {
    switch (inputMode) {
      case 'per_side':
        return reps * 2;
      case 'standard':
      default:
        return reps;
    }
  }

  double _getSetWorkload({
    required String inputMode,
    required int reps,
    required double weight,
  }) {
    switch (inputMode) {
      case 'per_side':
        return weight * reps * 2;
      case 'standard':
      default:
        return weight * reps;
    }
  }

  double _calculateLiftScore({
    required String scoreType,
    required int effectiveTotalReps,
    required double weightSum,
    required double? scoreMultiplier,
  }) {
    switch (scoreType) {
      case 'multiplier':
        if (scoreMultiplier == null) {
          throw Exception(
            'score_multiplier_snapshot is required for multiplier score type.',
          );
        }

        return weightSum * effectiveTotalReps * scoreMultiplier;

      case 'bodyweight':
        return effectiveTotalReps + (weightSum * 0.5);

      default:
        throw UnsupportedError('Unsupported score_type: $scoreType');
    }
  }

  Future<Map<String, Object?>> _getLiftInstanceById(
      Transaction txn,
      int liftInstanceId,
      ) async {
    final rows = await txn.query(
      TableNames.liftInstances,
      where: 'id = ?',
      whereArgs: [liftInstanceId],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw Exception('Missing lift_instance for id: $liftInstanceId');
    }

    return rows.first;
  }

  Future<int> _getWorkoutInstanceIdForLiftInstance(
      Transaction txn,
      int liftInstanceId,
      ) async {
    final rows = await txn.query(
      TableNames.liftInstances,
      columns: ['workout_instance_id'],
      where: 'id = ?',
      whereArgs: [liftInstanceId],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw Exception('Missing workout_instance_id for lift_instance_id: $liftInstanceId');
    }

    return rows.first['workout_instance_id'] as int;
  }
}