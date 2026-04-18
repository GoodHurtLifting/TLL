import 'package:sqflite/sqflite.dart';

import '../db/db_service.dart';
import '../db/table_names.dart';

class BlockSummaryQueryService {
  BlockSummaryQueryService._();

  static final BlockSummaryQueryService instance =
  BlockSummaryQueryService._();

  Future<Map<String, Object?>> getBlockSummaryData({
    required int blockInstanceId,
  }) async {
    final db = await DbService.instance.database;

    return db.transaction((txn) async {
      final block = await _getBlockHeader(
        txn,
        blockInstanceId: blockInstanceId,
      );

      final blockTotals = await _getBlockTotals(
        txn,
        blockInstanceId: blockInstanceId,
      );

      final workoutRows = await _getWorkoutRows(
        txn,
        blockInstanceId: blockInstanceId,
      );

      final improvementMetrics = _buildImprovementMetrics(workoutRows);

      return {
        'block': block,
        'block_totals': blockTotals,
        'workouts': workoutRows,
        'improvement_metrics': improvementMetrics,
      };
    });
  }

  Future<Map<String, Object?>> _getBlockHeader(
      Transaction txn, {
        required int blockInstanceId,
      }) async {
    final rows = await txn.rawQuery(
      '''
      SELECT
        bi.id,
        bi.run_number,
        bi.title_snapshot,
        bi.started_at,
        bi.completed_at,
        bi.status,
        bt.category
      FROM ${TableNames.blockInstances} bi
      INNER JOIN ${TableNames.blockTemplates} bt
        ON bt.id = bi.block_template_id
      WHERE bi.id = ?
      LIMIT 1
      ''',
      [blockInstanceId],
    );

    if (rows.isEmpty) {
      throw Exception(
        'Missing block_instance for summary query: $blockInstanceId',
      );
    }

    return rows.first;
  }

  Future<Map<String, Object?>> _getBlockTotals(
      Transaction txn, {
        required int blockInstanceId,
      }) async {
    final rows = await txn.query(
      TableNames.blockTotals,
      where: 'block_instance_id = ?',
      whereArgs: [blockInstanceId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return {
        'block_instance_id': blockInstanceId,
        'total_workload': 0.0,
        'block_score': 0.0,
        'completed_workout_count': 0,
        'total_workout_count': 0,
        'training_days': 0,
      };
    }

    return rows.first;
  }

  Future<List<Map<String, Object?>>> _getWorkoutRows(
      Transaction txn, {
        required int blockInstanceId,
      }) async {
    final rows = await txn.rawQuery(
      '''
      SELECT
        wi.id,
        wi.workout_template_id,
        wi.workout_slot_index,
        wi.week_index,
        wi.day_label,
        wi.title_snapshot,
        wi.status,
        wi.completed_at,
        COALESCE(wt.total_workload, 0) AS total_workload,
        COALESCE(wt.workout_score, 0) AS workout_score
      FROM ${TableNames.workoutInstances} wi
      LEFT JOIN ${TableNames.workoutTotals} wt
        ON wt.workout_instance_id = wi.id
      WHERE wi.block_instance_id = ?
      ORDER BY wi.workout_slot_index ASC
      ''',
      [blockInstanceId],
    );

    return rows;
  }

  Map<String, Object?> _buildImprovementMetrics(
      List<Map<String, Object?>> workouts,
      ) {
    if (workouts.isEmpty) {
      return {
        'best_workout_title': '-',
        'best_workout_score': 0.0,
        'highest_workload_title': '-',
        'highest_workload': 0.0,
        'most_improved_title': '-',
        'most_improved_delta': 0.0,
      };
    }

    Map<String, Object?> bestWorkout = workouts.first;
    double bestWorkoutScore =
    ((bestWorkout['workout_score'] as num?) ?? 0).toDouble();

    Map<String, Object?> highestWorkloadWorkout = workouts.first;
    double highestWorkoutWorkload =
    ((highestWorkloadWorkout['total_workload'] as num?) ?? 0).toDouble();

    final Map<int, List<Map<String, Object?>>> byTemplate = {};

    for (final workout in workouts) {
      final score = ((workout['workout_score'] as num?) ?? 0).toDouble();
      final workload = ((workout['total_workload'] as num?) ?? 0).toDouble();
      final templateId = workout['workout_template_id'] as int;

      if (score > bestWorkoutScore) {
        bestWorkout = workout;
        bestWorkoutScore = score;
      }

      if (workload > highestWorkoutWorkload) {
        highestWorkloadWorkout = workout;
        highestWorkoutWorkload = workload;
      }

      byTemplate.putIfAbsent(templateId, () => []).add(workout);
    }

    String mostImprovedTitle = '-';
    double mostImprovedDelta = 0.0;

    for (final entry in byTemplate.entries) {
      final templateWorkouts = entry.value;

      if (templateWorkouts.length < 2) {
        continue;
      }

      final firstScore =
      ((templateWorkouts.first['workout_score'] as num?) ?? 0).toDouble();

      double bestScoreInSeries = firstScore;
      for (final workout in templateWorkouts.skip(1)) {
        final score = ((workout['workout_score'] as num?) ?? 0).toDouble();
        if (score > bestScoreInSeries) {
          bestScoreInSeries = score;
        }
      }

      final delta = bestScoreInSeries - firstScore;
      if (delta > mostImprovedDelta) {
        mostImprovedDelta = delta;
        mostImprovedTitle =
            templateWorkouts.first['title_snapshot'] as String? ?? '-';
      }
    }

    return {
      'best_workout_title': bestWorkout['title_snapshot'] as String? ?? '-',
      'best_workout_score': bestWorkoutScore,
      'highest_workload_title':
      highestWorkloadWorkout['title_snapshot'] as String? ?? '-',
      'highest_workload': highestWorkoutWorkload,
      'most_improved_title': mostImprovedTitle,
      'most_improved_delta': mostImprovedDelta,
    };
  }
}