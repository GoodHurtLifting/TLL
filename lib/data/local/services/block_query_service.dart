import 'package:sqflite/sqflite.dart';

import '../db/db_service.dart';
import '../db/table_names.dart';

class BlockQueryService {
  BlockQueryService._();

  static final BlockQueryService instance = BlockQueryService._();

  Future<Map<String, Object?>> getBlockDashboardData({
    required int blockInstanceId,
  }) async {
    final db = await DbService.instance.database;

    return db.transaction((txn) async {
      final block = await _getBlockHeader(
        txn,
        blockInstanceId: blockInstanceId,
      );

      final workouts = await _getBlockWorkoutRows(
        txn,
        blockInstanceId: blockInstanceId,
      );

      final blockTotals = await _getBlockTotals(
        txn,
        blockInstanceId: blockInstanceId,
      );

      return {
        'block': block,
        'workouts': workouts,
        'block_totals': blockTotals,
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
        bi.user_id,
        bi.block_template_id,
        bi.run_number,
        bi.title_snapshot,
        bi.started_at,
        bi.completed_at,
        bi.status,
        bi.created_at,
        bi.updated_at,
        bt.category,
        bt.schedule_type,
        bt.num_weeks,
        bt.workouts_per_week,
        bt.total_workout_slots
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
        'Missing block_instance for dashboard query: $blockInstanceId',
      );
    }

    return rows.first;
  }

  Future<List<Map<String, Object?>>> _getBlockWorkoutRows(
      Transaction txn, {
        required int blockInstanceId,
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
        COALESCE(wt.total_workload, 0) AS total_workload,
        COALESCE(wt.workout_score, 0) AS workout_score,
        COALESCE(wt.completed_lift_count, 0) AS completed_lift_count,
        COALESCE(wt.total_lift_count, 0) AS total_lift_count
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
}