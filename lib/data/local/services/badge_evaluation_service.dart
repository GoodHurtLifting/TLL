import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../badges/badge_definitions.dart';
import '../db/db_service.dart';
import '../db/table_names.dart';

class BadgeEvaluationService {
  BadgeEvaluationService._();

  static final BadgeEvaluationService instance = BadgeEvaluationService._();

  static const _trackedLunchLadyLiftKeys = {
    'squat',
    'bench_press',
    'deadlift',
  };

  static const _meatWagonStepLbs = 100000;

  Future<void> evaluateAfterSetLogged({
    required int liftInstanceId,
    required int setIndex,
  }) async {
    final db = await DbService.instance.database;

    await db.transaction((txn) async {
      final context = await _getSetContext(
        txn,
        liftInstanceId: liftInstanceId,
        setIndex: setIndex,
      );

      if (context == null) {
        return;
      }

      await _evaluateLunchLady(
        txn,
        context: context,
      );

      await _evaluateMeatWagon(
        txn,
        userId: context.userId,
        blockInstanceId: context.blockInstanceId,
        sourceType: 'lift_log',
        sourceId: '${context.liftInstanceId}:${context.setIndex}',
      );
    });
  }

  Future<void> evaluateAfterWorkoutCompleted({
    required int workoutInstanceId,
  }) async {
    final db = await DbService.instance.database;

    await db.transaction((txn) async {
      final context = await _getWorkoutContext(
        txn,
        workoutInstanceId: workoutInstanceId,
      );

      if (context == null) {
        return;
      }

      await _evaluatePunchCard(
        txn,
        userId: context.userId,
        blockInstanceId: context.blockInstanceId,
      );
    });
  }

  Future<List<Map<String, Object?>>> getAwardsForBlockInstance({
    required int blockInstanceId,
  }) async {
    final db = await DbService.instance.database;

    return db.query(
      TableNames.badgeAwards,
      where: 'block_instance_id = ?',
      whereArgs: [blockInstanceId],
      orderBy: 'awarded_at ASC, id ASC',
    );
  }

  Future<int> getTotalBadgeCountForUser({
    required String userId,
  }) async {
    final db = await DbService.instance.database;

    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total_count
      FROM ${TableNames.badgeAwards}
      WHERE user_id = ?
      ''',
      [userId],
    );

    return (rows.first['total_count'] as int?) ?? 0;
  }

  Future<void> _evaluateMeatWagon(
    Transaction txn, {
    required String userId,
    required int blockInstanceId,
    required String sourceType,
    required String sourceId,
  }) async {
    final totalWorkloadRows = await txn.rawQuery(
      '''
      SELECT COALESCE(SUM(wt.total_workload), 0) AS total_workload
      FROM ${TableNames.workoutTotals} wt
      INNER JOIN ${TableNames.workoutInstances} wi
        ON wi.id = wt.workout_instance_id
      INNER JOIN ${TableNames.blockInstances} bi
        ON bi.id = wi.block_instance_id
      WHERE bi.user_id = ?
      ''',
      [userId],
    );

    final lifetimeWorkload =
        ((totalWorkloadRows.first['total_workload'] as num?) ?? 0).toDouble();

    final thresholdCount = lifetimeWorkload ~/ _meatWagonStepLbs;
    if (thresholdCount <= 0) {
      return;
    }

    final existingRows = await txn.rawQuery(
      '''
      SELECT COUNT(*) AS award_count
      FROM ${TableNames.badgeAwards}
      WHERE user_id = ?
        AND badge_key = ?
      ''',
      [userId, BadgeKeys.meatWagon],
    );

    final existingCount = (existingRows.first['award_count'] as int?) ?? 0;

    if (thresholdCount <= existingCount) {
      return;
    }

    for (var nextIndex = existingCount + 1;
        nextIndex <= thresholdCount;
        nextIndex++) {
      final thresholdLbs = nextIndex * _meatWagonStepLbs;

      await _insertBadgeAward(
        txn,
        badgeKey: BadgeKeys.meatWagon,
        userId: userId,
        sourceType: sourceType,
        sourceId: sourceId,
        blockInstanceId: blockInstanceId,
        metadata: {
          'threshold_lbs': thresholdLbs,
          'lifetime_workload_lbs': lifetimeWorkload,
        },
      );
    }
  }

  Future<void> _evaluateLunchLady(
    Transaction txn, {
    required _SetContext context,
  }) async {
    if (!_trackedLunchLadyLiftKeys.contains(context.liftKey)) {
      return;
    }

    final newWeight = context.weight;

    final existingPrRows = await txn.query(
      TableNames.liftWeightPrCache,
      columns: ['heaviest_weight'],
      where: 'user_id = ? AND lift_key = ?',
      whereArgs: [context.userId, context.liftKey],
      limit: 1,
    );

    final previousPr = existingPrRows.isEmpty
        ? 0.0
        : ((existingPrRows.first['heaviest_weight'] as num?) ?? 0).toDouble();

    if (newWeight <= previousPr) {
      return;
    }

    await txn.insert(
      TableNames.liftWeightPrCache,
      {
        'user_id': context.userId,
        'lift_key': context.liftKey,
        'heaviest_weight': newWeight,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _insertBadgeAward(
      txn,
      badgeKey: BadgeKeys.lunchLady,
      userId: context.userId,
      sourceType: 'lift_log',
      sourceId: '${context.liftInstanceId}:${context.setIndex}',
      blockInstanceId: context.blockInstanceId,
      metadata: {
        'lift_key': context.liftKey,
        'previous_pr_lbs': previousPr,
        'new_pr_lbs': newWeight,
      },
    );
  }

  Future<void> _evaluatePunchCard(
    Transaction txn, {
    required String userId,
    required int blockInstanceId,
  }) async {
    final completedRows = await txn.rawQuery(
      '''
      SELECT wi.completed_at
      FROM ${TableNames.workoutInstances} wi
      INNER JOIN ${TableNames.blockInstances} bi
        ON bi.id = wi.block_instance_id
      WHERE bi.user_id = ?
        AND wi.completed_at IS NOT NULL
        AND wi.completed_at != ''
      ORDER BY wi.completed_at ASC
      ''',
      [userId],
    );

    final sessionsPerWeek = <DateTime, int>{};

    for (final row in completedRows) {
      final completedAtRaw = row['completed_at'] as String?;
      if (completedAtRaw == null || completedAtRaw.isEmpty) {
        continue;
      }

      final completedAt = DateTime.parse(completedAtRaw).toUtc();
      final weekStart = _startOfWeekUtc(completedAt);

      sessionsPerWeek[weekStart] = (sessionsPerWeek[weekStart] ?? 0) + 1;
    }

    if (sessionsPerWeek.isEmpty) {
      return;
    }

    final sortedWeeks = sessionsPerWeek.keys.toList()..sort();
    final qualifyingWindowEnds = <DateTime>[];

    for (var i = 0; i <= sortedWeeks.length - 4; i++) {
      final window = sortedWeeks.sublist(i, i + 4);

      var isConsecutive = true;
      var meetsVolume = true;

      for (var j = 0; j < window.length; j++) {
        if ((sessionsPerWeek[window[j]] ?? 0) < 3) {
          meetsVolume = false;
          break;
        }

        if (j > 0) {
          final daysBetween = window[j].difference(window[j - 1]).inDays;
          if (daysBetween != 7) {
            isConsecutive = false;
            break;
          }
        }
      }

      if (meetsVolume && isConsecutive) {
        qualifyingWindowEnds.add(window.last);
      }
    }

    if (qualifyingWindowEnds.isEmpty) {
      return;
    }

    final existingRows = await txn.rawQuery(
      '''
      SELECT COUNT(*) AS award_count
      FROM ${TableNames.badgeAwards}
      WHERE user_id = ?
        AND badge_key = ?
      ''',
      [userId, BadgeKeys.punchCard],
    );

    final existingCount = (existingRows.first['award_count'] as int?) ?? 0;

    if (qualifyingWindowEnds.length <= existingCount) {
      return;
    }

    for (var i = existingCount; i < qualifyingWindowEnds.length; i++) {
      final weekEnd = qualifyingWindowEnds[i];
      final weekStart = weekEnd.subtract(const Duration(days: 21));

      await _insertBadgeAward(
        txn,
        badgeKey: BadgeKeys.punchCard,
        userId: userId,
        sourceType: 'workout_week_streak',
        sourceId: weekEnd.toIso8601String(),
        blockInstanceId: blockInstanceId,
        metadata: {
          'window_start_week_utc': weekStart.toIso8601String(),
          'window_end_week_utc': weekEnd.toIso8601String(),
          'required_workouts_per_week': 3,
          'required_consecutive_weeks': 4,
        },
      );
    }
  }

  Future<_SetContext?> _getSetContext(
    Transaction txn, {
    required int liftInstanceId,
    required int setIndex,
  }) async {
    final rows = await txn.rawQuery(
      '''
      SELECT
        li.id AS lift_instance_id,
        bi.id AS block_instance_id,
        bi.user_id,
        lc.lift_key,
        ll.weight
      FROM ${TableNames.liftInstances} li
      INNER JOIN ${TableNames.workoutInstances} wi
        ON wi.id = li.workout_instance_id
      INNER JOIN ${TableNames.blockInstances} bi
        ON bi.id = wi.block_instance_id
      INNER JOIN ${TableNames.workoutTemplateLifts} wtl
        ON wtl.id = li.workout_template_lift_id
      INNER JOIN ${TableNames.liftCatalog} lc
        ON lc.id = wtl.lift_catalog_id
      INNER JOIN ${TableNames.liftLogs} ll
        ON ll.lift_instance_id = li.id
      WHERE li.id = ?
        AND ll.set_index = ?
      LIMIT 1
      ''',
      [liftInstanceId, setIndex],
    );

    if (rows.isEmpty) {
      return null;
    }

    final row = rows.first;

    return _SetContext(
      liftInstanceId: row['lift_instance_id'] as int,
      blockInstanceId: row['block_instance_id'] as int,
      userId: row['user_id'] as String,
      liftKey: row['lift_key'] as String,
      setIndex: setIndex,
      weight: ((row['weight'] as num?) ?? 0).toDouble(),
    );
  }

  Future<_WorkoutContext?> _getWorkoutContext(
    Transaction txn, {
    required int workoutInstanceId,
  }) async {
    final rows = await txn.rawQuery(
      '''
      SELECT
        wi.block_instance_id,
        bi.user_id
      FROM ${TableNames.workoutInstances} wi
      INNER JOIN ${TableNames.blockInstances} bi
        ON bi.id = wi.block_instance_id
      WHERE wi.id = ?
      LIMIT 1
      ''',
      [workoutInstanceId],
    );

    if (rows.isEmpty) {
      return null;
    }

    final row = rows.first;
    return _WorkoutContext(
      blockInstanceId: row['block_instance_id'] as int,
      userId: row['user_id'] as String,
    );
  }

  Future<void> _insertBadgeAward(
    Transaction txn, {
    required String badgeKey,
    required String userId,
    required String sourceType,
    required String sourceId,
    required int? blockInstanceId,
    Map<String, Object?>? metadata,
  }) async {
    await txn.insert(
      TableNames.badgeAwards,
      {
        'badge_key': badgeKey,
        'user_id': userId,
        'awarded_at': DateTime.now().toIso8601String(),
        'source_type': sourceType,
        'source_id': sourceId,
        'block_instance_id': blockInstanceId,
        'metadata_json': metadata == null ? null : jsonEncode(metadata),
      },
    );
  }

  DateTime _startOfWeekUtc(DateTime value) {
    final date = DateTime.utc(value.year, value.month, value.day);
    final daysToMonday = date.weekday - DateTime.monday;
    return date.subtract(Duration(days: daysToMonday));
  }
}

class _SetContext {
  const _SetContext({
    required this.liftInstanceId,
    required this.blockInstanceId,
    required this.userId,
    required this.liftKey,
    required this.setIndex,
    required this.weight,
  });

  final int liftInstanceId;
  final int blockInstanceId;
  final String userId;
  final String liftKey;
  final int setIndex;
  final double weight;
}

class _WorkoutContext {
  const _WorkoutContext({
    required this.blockInstanceId,
    required this.userId,
  });

  final int blockInstanceId;
  final String userId;
}
