import 'package:sqflite/sqflite.dart';

import '../db/db_service.dart';
import '../db/table_names.dart';

class BlockInstanceService {
  BlockInstanceService._();

  static final BlockInstanceService instance = BlockInstanceService._();

  Future<int> createBlockInstanceFromBlockKey({
    required String userId,
    required String blockKey,
  }) async {
    final db = await DbService.instance.database;

    return db.transaction((txn) async {
      final blockTemplate = await _getBlockTemplateByKey(txn, blockKey);
      final blockTemplateId = blockTemplate['id'] as int;
      final titleSnapshot = blockTemplate['title'] as String;
      final numWeeks = blockTemplate['num_weeks'] as int;
      final scheduleType = blockTemplate['schedule_type'] as String;
      final workoutsPerWeek =
          (blockTemplate['workouts_per_week'] as int?) ?? 3;
      final totalWorkoutSlots =
          (blockTemplate['total_workout_slots'] as int?) ??
              (numWeeks * workoutsPerWeek);

      final workoutTemplates = await _getWorkoutTemplatesForBlock(
        txn,
        blockTemplateId,
      );

      if (workoutTemplates.isEmpty) {
        throw Exception(
          'No workout_templates found for block_template_id: $blockTemplateId',
        );
      }

      final runNumber = await _getNextRunNumber(
        txn,
        userId: userId,
        blockTemplateId: blockTemplateId,
      );

      final now = DateTime.now().toIso8601String();

      final blockInstanceId = await txn.insert(
        TableNames.blockInstances,
        {
          'user_id': userId,
          'block_template_id': blockTemplateId,
          'run_number': runNumber,
          'title_snapshot': titleSnapshot,
          'started_at': null,
          'completed_at': null,
          'status': 'active',
          'created_at': now,
          'updated_at': now,
        },
      );

      final scheduledSlots = _buildWorkoutSchedule(
        scheduleType: scheduleType,
        workoutTemplates: workoutTemplates,
        numWeeks: numWeeks,
        workoutsPerWeek: workoutsPerWeek,
        totalWorkoutSlots: totalWorkoutSlots,
      );

      for (var i = 0; i < scheduledSlots.length; i++) {
        final slot = scheduledSlots[i];

        final workoutInstanceId = await txn.insert(
          TableNames.workoutInstances,
          {
            'block_instance_id': blockInstanceId,
            'workout_template_id': slot.workoutTemplateId,
            'workout_slot_index': i,
            'week_index': slot.weekIndex,
            'day_label': slot.dayLabel,
            'title_snapshot': slot.titleSnapshot,
            'started_at': null,
            'completed_at': null,
            'status': 'not_started',
            'created_at': now,
            'updated_at': now,
          },
        );

        final templateLifts = await _getWorkoutTemplateLiftsWithCatalog(
          txn,
          slot.workoutTemplateId,
        );

        for (final lift in templateLifts) {
          final liftName = lift['catalog_name'] as String;
          final repScheme = lift['rep_scheme'] as String;
          final liftInfoSnapshot =
              (lift['lift_info'] as String?) ??
                  (lift['catalog_lift_info'] as String?);

          final scoreTypeSnapshot =
              (lift['score_type'] as String?) ??
                  (lift['catalog_score_type'] as String);

          final scoreMultiplierSnapshot =
              (lift['score_multiplier'] as num?);

          final scoreMultiplierModeSnapshot =
              (lift['score_multiplier_mode'] as String?) ?? 'per_lift';

          final inputModeSnapshot =
              (lift['input_mode'] as String?) ??
                  (lift['catalog_input_mode'] as String? ?? 'standard');

          await txn.insert(
            TableNames.liftInstances,
            {
              'workout_instance_id': workoutInstanceId,
              'workout_template_lift_id': lift['id'] as int,
              'sequence_index': lift['sequence_index'] as int,
              'lift_name_snapshot': liftName,
              'rep_scheme_snapshot': repScheme,
              'lift_info_snapshot': liftInfoSnapshot,
              'score_type_snapshot': scoreTypeSnapshot,
              'score_multiplier_snapshot': scoreMultiplierSnapshot?.toDouble(),
              'score_multiplier_mode_snapshot': scoreMultiplierModeSnapshot,
              'input_mode_snapshot': inputModeSnapshot,
              'reference_source_snapshot': lift['reference_source'] as String?,
              'reference_lift_key_snapshot':
              lift['reference_lift_key'] as String?,
              'percent_value_snapshot':
              (lift['percent_value'] as num?)?.toDouble(),
              'created_at': now,
              'updated_at': now,
            },
          );
        }
      }

      return blockInstanceId;
    });
  }

  Future<Map<String, Object?>> _getBlockTemplateByKey(
      Transaction txn,
      String blockKey,
      ) async {
    final rows = await txn.query(
      TableNames.blockTemplates,
      where: 'block_key = ?',
      whereArgs: [blockKey],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw Exception('Missing block_template for key: $blockKey');
    }

    return rows.first;
  }

  Future<int> _getNextRunNumber(
      Transaction txn, {
        required String userId,
        required int blockTemplateId,
      }) async {
    final rows = await txn.rawQuery(
      '''
      SELECT MAX(run_number) AS max_run
      FROM ${TableNames.blockInstances}
      WHERE user_id = ? AND block_template_id = ?
      ''',
      [userId, blockTemplateId],
    );

    final maxRun = rows.first['max_run'] as int?;
    return (maxRun ?? 0) + 1;
  }

  Future<List<Map<String, Object?>>> _getWorkoutTemplatesForBlock(
      Transaction txn,
      int blockTemplateId,
      ) async {
    return txn.query(
      TableNames.workoutTemplates,
      where: 'block_template_id = ?',
      whereArgs: [blockTemplateId],
      orderBy: 'sequence_index ASC',
    );
  }

  Future<List<Map<String, Object?>>> _getWorkoutTemplateLiftsWithCatalog(
      Transaction txn,
      int workoutTemplateId,
      ) async {
    final rows = await txn.rawQuery(
      '''
      SELECT
        wtl.id,
        wtl.workout_template_id,
        wtl.lift_catalog_id,
        wtl.sequence_index,
        wtl.rep_scheme,
        wtl.lift_info,
        wtl.score_type,
        wtl.score_multiplier,
        wtl.score_multiplier_mode,
        wtl.input_mode,
        wtl.reference_source,
        wtl.reference_lift_key,
        wtl.percent_value,
        lc.name AS catalog_name,
        lc.lift_info AS catalog_lift_info,
        lc.score_type AS catalog_score_type,
        lc.input_mode AS catalog_input_mode
      FROM ${TableNames.workoutTemplateLifts} wtl
      INNER JOIN ${TableNames.liftCatalog} lc
        ON lc.id = wtl.lift_catalog_id
      WHERE wtl.workout_template_id = ?
      ORDER BY wtl.sequence_index ASC
      ''',
      [workoutTemplateId],
    );

    return rows;
  }

  List<_ScheduledWorkoutSlot> _buildWorkoutSchedule({
    required String scheduleType,
    required List<Map<String, Object?>> workoutTemplates,
    required int numWeeks,
    required int workoutsPerWeek,
    required int totalWorkoutSlots,
  }) {
    switch (scheduleType) {
      case 'three_day_standard':
        return _buildThreeDayStandardSchedule(
          workoutTemplates: workoutTemplates,
          numWeeks: numWeeks,
          workoutsPerWeek: workoutsPerWeek,
          totalWorkoutSlots: totalWorkoutSlots,
        );

      case 'two_workout_alternating':
        return _buildTwoWorkoutAlternatingSchedule(
          workoutTemplates: workoutTemplates,
          numWeeks: numWeeks,
        );

      case 'ppl_plus_condensed':
        throw UnimplementedError(
          'ppl_plus_condensed needs a more explicit cadence rule before generation.',
        );

      case 'texas_method':
        throw UnimplementedError(
          'texas_method needs explicit week-to-template mapping before generation.',
        );

      default:
        throw UnsupportedError('Unsupported schedule_type: $scheduleType');
    }
  }

  List<_ScheduledWorkoutSlot> _buildThreeDayStandardSchedule({
    required List<Map<String, Object?>> workoutTemplates,
    required int numWeeks,
    required int workoutsPerWeek,
    required int totalWorkoutSlots,
  }) {
    final slots = <_ScheduledWorkoutSlot>[];

    for (var slotIndex = 0; slotIndex < totalWorkoutSlots; slotIndex++) {
      final workout = workoutTemplates[slotIndex % workoutTemplates.length];
      final weekIndex = slotIndex ~/ workoutsPerWeek;
      final slotIndexInWeek = slotIndex % workoutsPerWeek;

      slots.add(
        _ScheduledWorkoutSlot(
          workoutTemplateId: workout['id'] as int,
          titleSnapshot: workout['title'] as String,
          weekIndex: weekIndex,
          dayLabel: _defaultDayLabel(
            weekNumber: weekIndex + 1,
            slotNumberInWeek: slotIndexInWeek + 1,
          ),
        ),
      );
    }

    return slots;
  }

  List<_ScheduledWorkoutSlot> _buildTwoWorkoutAlternatingSchedule({
    required List<Map<String, Object?>> workoutTemplates,
    required int numWeeks,
  }) {
    if (workoutTemplates.length < 2) {
      throw Exception(
        'two_workout_alternating requires at least 2 workout templates.',
      );
    }

    final workoutA = workoutTemplates[0];
    final workoutB = workoutTemplates[1];

    final slots = <_ScheduledWorkoutSlot>[];

    for (var weekIndex = 0; weekIndex < numWeeks; weekIndex++) {
      final isOddPatternWeek = weekIndex.isEven;
      final weeklyPattern = isOddPatternWeek
          ? [workoutA, workoutB, workoutA]
          : [workoutB, workoutA, workoutB];

      for (var slotIndexInWeek = 0; slotIndexInWeek < weeklyPattern.length; slotIndexInWeek++) {
        final workout = weeklyPattern[slotIndexInWeek];

        slots.add(
          _ScheduledWorkoutSlot(
            workoutTemplateId: workout['id'] as int,
            titleSnapshot: workout['title'] as String,
            weekIndex: weekIndex,
            dayLabel: _defaultDayLabel(
              weekNumber: weekIndex + 1,
              slotNumberInWeek: slotIndexInWeek + 1,
            ),
          ),
        );
      }
    }

    return slots;
  }

  String _defaultDayLabel({
    required int weekNumber,
    required int slotNumberInWeek,
  }) {
    return 'Week $weekNumber - Slot $slotNumberInWeek';
  }
}

class _ScheduledWorkoutSlot {
  final int workoutTemplateId;
  final String titleSnapshot;
  final int weekIndex;
  final String dayLabel;

  const _ScheduledWorkoutSlot({
    required this.workoutTemplateId,
    required this.titleSnapshot,
    required this.weekIndex,
    required this.dayLabel,
  });
}
