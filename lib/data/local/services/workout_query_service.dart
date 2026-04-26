import 'package:sqflite/sqflite.dart';

import '../db/db_service.dart';
import '../db/table_names.dart';

class WorkoutQueryService {
  WorkoutQueryService._();

  static final WorkoutQueryService instance = WorkoutQueryService._();

  Future<Map<String, Object?>> getWorkoutLogData({
    required int workoutInstanceId,
  }) async {
    final db = await DbService.instance.database;

    return db.transaction((txn) async {
      final workout = await _getWorkoutHeader(
        txn,
        workoutInstanceId: workoutInstanceId,
      );

      final lifts = await _getWorkoutLiftBundles(
        txn,
        workoutInstanceId: workoutInstanceId,
      );

      final workoutTotals = await _getWorkoutTotals(
        txn,
        workoutInstanceId: workoutInstanceId,
      );

      final previousWorkoutTotals = await _getPreviousWorkoutTotals(
        txn,
        workoutHeader: workout,
      );

      return {
        'workout': workout,
        'lifts': lifts,
        'workout_totals': workoutTotals,
        'previous_workout_totals': previousWorkoutTotals,
      };
    });
  }

  Future<Map<String, Object?>> getLiftTotals({
    required int liftInstanceId,
  }) async {
    final db = await DbService.instance.database;
    final rows = await db.query(
      TableNames.liftTotals,
      where: 'lift_instance_id = ?',
      whereArgs: [liftInstanceId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return {
        'lift_instance_id': liftInstanceId,
        'total_reps': 0,
        'total_workload': 0.0,
        'total_score': 0.0,
      };
    }

    return rows.first;
  }

  Future<Map<String, Object?>> getWorkoutTotals({
    required int workoutInstanceId,
  }) async {
    final db = await DbService.instance.database;
    final rows = await db.query(
      TableNames.workoutTotals,
      where: 'workout_instance_id = ?',
      whereArgs: [workoutInstanceId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return {
        'workout_instance_id': workoutInstanceId,
        'total_workload': 0.0,
        'workout_score': 0.0,
        'completed_lift_count': 0,
        'total_lift_count': 0,
      };
    }

    return rows.first;
  }

  Future<Map<String, Object?>> _getWorkoutHeader(
      Transaction txn, {
        required int workoutInstanceId,
      }) async {
    final rows = await txn.rawQuery(
      '''
      SELECT
        wi.id,
        wi.block_instance_id,
        wi.workout_template_id,
        wi.workout_slot_index,
        wi.week_index,
        wi.day_label,
        wi.title_snapshot,
        wi.started_at,
        wi.completed_at,
        wi.status,
        wi.created_at,
        wi.updated_at,
        bi.user_id,
        bi.run_number,
        bi.title_snapshot AS block_title_snapshot
      FROM ${TableNames.workoutInstances} wi
      INNER JOIN ${TableNames.blockInstances} bi
        ON bi.id = wi.block_instance_id
      WHERE wi.id = ?
      LIMIT 1
      ''',
      [workoutInstanceId],
    );

    if (rows.isEmpty) {
      throw Exception(
        'Missing workout_instance for workout query: $workoutInstanceId',
      );
    }

    return rows.first;
  }

  Future<List<Map<String, Object?>>> _getWorkoutLiftBundles(
      Transaction txn, {
        required int workoutInstanceId,
      }) async {
    final workoutHeader = await _getWorkoutHeader(
      txn,
      workoutInstanceId: workoutInstanceId,
    );

    final userId = workoutHeader['user_id'] as String;
    final currentWorkoutTemplateId = workoutHeader['workout_template_id'] as int;

    final liftInstances = await txn.query(
      TableNames.liftInstances,
      where: 'workout_instance_id = ?',
      whereArgs: [workoutInstanceId],
      orderBy: 'sequence_index ASC',
    );

    final bundles = <Map<String, Object?>>[];

    for (final liftInstance in liftInstances) {
      final liftInstanceId = liftInstance['id'] as int;
      final workoutTemplateLiftId =
      liftInstance['workout_template_lift_id'] as int;

      final logs = await txn.query(
        TableNames.liftLogs,
        where: 'lift_instance_id = ?',
        whereArgs: [liftInstanceId],
        orderBy: 'set_index ASC',
      );

      final totalsRows = await txn.query(
        TableNames.liftTotals,
        where: 'lift_instance_id = ?',
        whereArgs: [liftInstanceId],
        limit: 1,
      );

      final totals = totalsRows.isEmpty
          ? {
        'lift_instance_id': liftInstanceId,
        'total_reps': 0,
        'total_workload': 0.0,
        'total_score': 0.0,
      }
          : totalsRows.first;

      final previousData = await _getPreviousLiftData(
        txn,
        currentWorkoutInstanceId: workoutInstanceId,
        currentWorkoutTemplateId: currentWorkoutTemplateId,
        workoutTemplateLiftId: workoutTemplateLiftId,
        userId: userId,
      );

      final percentValue =
      (liftInstance['percent_value'] as num?)?.toDouble();

      double? recommendedWeight;

      if (percentValue != null &&
          previousData['average_weight'] != null) {
        final baseWeight =
        (previousData['average_weight'] as num).toDouble();

        final raw = baseWeight * percentValue;

        // round to nearest 5
        recommendedWeight = (raw / 5).round() * 5;
      }

      bundles.add({
        'lift_instance': liftInstance,
        'logs': logs,
        'totals': totals,
        'previous': previousData,
        'recommended_weight': recommendedWeight,
      });
    }

    return bundles;
  }

  Future<Map<String, Object?>> _getPreviousLiftData(
      Transaction txn, {
        required int currentWorkoutInstanceId,
        required int currentWorkoutTemplateId,
        required int workoutTemplateLiftId,
        required String userId,
      }) async {
    final previousLiftRows = await txn.rawQuery(
      '''
      SELECT
        li.id AS lift_instance_id
      FROM ${TableNames.liftInstances} li
      INNER JOIN ${TableNames.workoutInstances} wi
        ON wi.id = li.workout_instance_id
      INNER JOIN ${TableNames.blockInstances} bi
        ON bi.id = wi.block_instance_id
      WHERE bi.user_id = ?
        AND wi.workout_template_id = ?
        AND li.workout_template_lift_id = ?
        AND wi.id < ?
      ORDER BY wi.id DESC
      LIMIT 1
      ''',
      [
        userId,
        currentWorkoutTemplateId,
        workoutTemplateLiftId,
        currentWorkoutInstanceId,
      ],
    );

    if (previousLiftRows.isEmpty) {
      return {
        'lift_instance_id': null,
        'average_weight': null,
        'logs': <Map<String, Object?>>[],
        'total_reps': 0,
        'total_workload': 0.0,
        'total_score': 0.0,
      };
    }

    final previousLiftInstanceId =
    previousLiftRows.first['lift_instance_id'] as int;

    final previousLogRows = await txn.query(
      TableNames.liftLogs,
      where: 'lift_instance_id = ?',
      whereArgs: [previousLiftInstanceId],
      orderBy: 'set_index ASC',
    );

    double? averageWeight;
    if (previousLogRows.isNotEmpty) {
      final weightSum = previousLogRows.fold<double>(
        0.0,
            (sum, row) => sum + (((row['weight'] as num?) ?? 0).toDouble()),
      );
      averageWeight = weightSum / previousLogRows.length;
    }

    final previousTotalsRows = await txn.query(
      TableNames.liftTotals,
      where: 'lift_instance_id = ?',
      whereArgs: [previousLiftInstanceId],
      limit: 1,
    );

    final previousTotals = previousTotalsRows.isEmpty
        ? {
      'total_reps': 0,
      'total_workload': 0.0,
      'total_score': 0.0,
    }
        : previousTotalsRows.first;

    return {
      'lift_instance_id': previousLiftInstanceId,
      'average_weight': averageWeight,
      'logs': previousLogRows,
      'total_reps': (previousTotals['total_reps'] as int?) ?? 0,
      'total_workload':
      ((previousTotals['total_workload'] as num?) ?? 0).toDouble(),
      'total_score': ((previousTotals['total_score'] as num?) ?? 0).toDouble(),
    };
  }

  Future<Map<String, Object?>> _getWorkoutTotals(
      Transaction txn, {
        required int workoutInstanceId,
      }) async {
    final rows = await txn.query(
      TableNames.workoutTotals,
      where: 'workout_instance_id = ?',
      whereArgs: [workoutInstanceId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return {
        'workout_instance_id': workoutInstanceId,
        'total_workload': 0.0,
        'workout_score': 0.0,
        'completed_lift_count': 0,
        'total_lift_count': 0,
      };
    }

    return rows.first;
  }

  Future<Map<String, Object?>> _getPreviousWorkoutTotals(
    Transaction txn, {
    required Map<String, Object?> workoutHeader,
  }) async {
    final userId = workoutHeader['user_id'] as String;
    final currentWorkoutInstanceId = workoutHeader['id'] as int;
    final currentWorkoutTemplateId = workoutHeader['workout_template_id'] as int;

    final previousWorkoutRows = await txn.rawQuery(
      '''
      SELECT wi.id
      FROM ${TableNames.workoutInstances} wi
      INNER JOIN ${TableNames.blockInstances} bi
        ON bi.id = wi.block_instance_id
      WHERE bi.user_id = ?
        AND wi.workout_template_id = ?
        AND wi.id < ?
      ORDER BY wi.id DESC
      LIMIT 1
      ''',
      [userId, currentWorkoutTemplateId, currentWorkoutInstanceId],
    );

    if (previousWorkoutRows.isEmpty) {
      return {
        'workout_instance_id': null,
        'total_workload': 0.0,
        'workout_score': 0.0,
        'completed_lift_count': 0,
        'total_lift_count': 0,
      };
    }

    final previousWorkoutInstanceId = previousWorkoutRows.first['id'] as int;
    final previousTotalsRows = await txn.query(
      TableNames.workoutTotals,
      where: 'workout_instance_id = ?',
      whereArgs: [previousWorkoutInstanceId],
      limit: 1,
    );

    if (previousTotalsRows.isEmpty) {
      return {
        'workout_instance_id': previousWorkoutInstanceId,
        'total_workload': 0.0,
        'workout_score': 0.0,
        'completed_lift_count': 0,
        'total_lift_count': 0,
      };
    }

    return previousTotalsRows.first;
  }
}
