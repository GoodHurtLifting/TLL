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

      return {
        'block': block,
        'block_totals': blockTotals,
        'workouts': workoutRows,
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
}