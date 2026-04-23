import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../data/local/services/badge_evaluation_service.dart';
import '../../../data/local/services/lift_logging_service.dart';
import '../../../data/local/services/workout_completion_service.dart';
import '../../../data/local/services/workout_query_service.dart';
import '../../blocks/presentation/block_summary_screen.dart';
import 'widgets/badge_award_dialog.dart';

class WorkoutLogScreen extends StatefulWidget {
  final int workoutInstanceId;

  const WorkoutLogScreen({
    super.key,
    required this.workoutInstanceId,
  });

  @override
  State<WorkoutLogScreen> createState() => _WorkoutLogScreenState();
}

class _WorkoutLogScreenState extends State<WorkoutLogScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _lunchLadyShown = false;
  bool _meatWagonShown = false;
  Map<String, Object?>? _workoutData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWorkout();
  }

  Future<void> _loadWorkout() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await WorkoutQueryService.instance.getWorkoutLogData(
        workoutInstanceId: widget.workoutInstanceId,
      );

      if (!mounted) return;

      setState(() {
        _workoutData = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSet({
    required int liftInstanceId,
    required int setIndex,
    required int reps,
    required double? weight,
  }) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await LiftLoggingService.instance.saveSetEntry(
        liftInstanceId: liftInstanceId,
        setIndex: setIndex,
        reps: reps,
        weight: weight,
      );

      await _loadWorkout();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
      setState(() {
        _isSaving = false;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _finishWorkout() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await WorkoutCompletionService.instance.startWorkout(
        workoutInstanceId: widget.workoutInstanceId,
      );

      final blockInstanceId =
      await WorkoutCompletionService.instance.getBlockInstanceIdForWorkout(
        workoutInstanceId: widget.workoutInstanceId,
      );

      await WorkoutCompletionService.instance.finishWorkout(
        workoutInstanceId: widget.workoutInstanceId,
      );

      final lunchLadyAwards =
      await BadgeEvaluationService.instance.getLunchLadyAwardsForWorkout(
        workoutInstanceId: widget.workoutInstanceId,
      );

      final shouldShowLunchLady =
          lunchLadyAwards.isNotEmpty && !_lunchLadyShown;
      if (shouldShowLunchLady) {
        _lunchLadyShown = true;
        if (!mounted) return;
        await _showLunchLadyBadgeDialog(lunchLadyAwards.last);
      }

      final meatWagonAwards =
      await BadgeEvaluationService.instance.getMeatWagonAwardsForBlock(
        blockInstanceId: blockInstanceId,
      );

      final shouldShowMeatWagon =
          meatWagonAwards.isNotEmpty && !_meatWagonShown;
      if (shouldShowMeatWagon) {
        _meatWagonShown = true;
        if (!mounted) return;
        await _showMeatWagonBadgeDialog(meatWagonAwards.last);
      }

      final isBlockComplete =
      await WorkoutCompletionService.instance.isBlockCompletedForWorkout(
        workoutInstanceId: widget.workoutInstanceId,
      );

      if (!mounted) return;

      if (isBlockComplete) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => BlockSummaryScreen(
              blockInstanceId: blockInstanceId,
            ),
          ),
        );
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Finish failed: $e')),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _showLunchLadyBadgeDialog(Map<String, Object?> award) async {
    final metadataRaw = award['metadata_json'] as String?;
    String? liftKey;

    if (metadataRaw != null && metadataRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(metadataRaw);
        if (decoded is Map<String, dynamic>) {
          liftKey = decoded['lift_key'] as String?;
        }
      } catch (_) {
        liftKey = null;
      }
    }

    final formattedLiftKey = liftKey == null ? null : _formatLiftKey(liftKey);

    await showBadgeAwardDialog(
      context: context,
      title: 'Lunch Lady',
      icon: Icons.emoji_events_outlined,
      message: 'New PR on a big 3 lift.',
      detail: formattedLiftKey == null ? null : 'Lift: $formattedLiftKey',
    );
  }

  Future<void> _showMeatWagonBadgeDialog(Map<String, Object?> award) async {
    final metadataRaw = award['metadata_json'] as String?;
    int? thresholdLbs;

    if (metadataRaw != null && metadataRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(metadataRaw);
        if (decoded is Map<String, dynamic>) {
          final rawThreshold = decoded['threshold_lbs'];
          if (rawThreshold is int) {
            thresholdLbs = rawThreshold;
          } else if (rawThreshold is double) {
            thresholdLbs = rawThreshold.toInt();
          }
        }
      } catch (_) {
        thresholdLbs = null;
      }
    }

    await showBadgeAwardDialog(
      context: context,
      title: 'Meat Wagon',
      icon: Icons.local_shipping_outlined,
      message: 'You crossed another lifetime workload milestone.',
      detail: thresholdLbs == null ? null : 'Milestone: $thresholdLbs lbs',
    );
  }

  String _formatLiftKey(String liftKey) {
    return liftKey
        .split('_')
        .map((segment) {
          if (segment.isEmpty) {
            return segment;
          }
          return '${segment[0].toUpperCase()}${segment.substring(1)}';
        })
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workout Log')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_error!),
          ),
        ),
      );
    }

    final workout = _workoutData!['workout'] as Map<String, Object?>;
    final lifts = _workoutData!['lifts'] as List<Map<String, Object?>>;
    final workoutTotals = _workoutData!['workout_totals'] as Map<String, Object?>;

    final blockTitle =
        (workout['block_title_snapshot'] as String?) ?? 'Block';
    final workoutTitle = (workout['title_snapshot'] as String?) ?? 'Workout';
    final runNumber = workout['run_number'];
    final dayLabel = (workout['day_label'] as String?) ?? '';
    final workoutScore =
    ((workoutTotals['workout_score'] as num?) ?? 0).toDouble();
    final totalWorkload =
    ((workoutTotals['total_workload'] as num?) ?? 0).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: Text('$blockTitle - $workoutTitle'),
      ),
      body: AbsorbPointer(
        absorbing: _isSaving,
        child: RefreshIndicator(
          onRefresh: _loadWorkout,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _WorkoutHeaderCard(
                blockTitle: blockTitle,
                workoutTitle: workoutTitle,
                runNumber: runNumber?.toString() ?? '-',
                dayLabel: dayLabel,
              ),
              const SizedBox(height: 12),
              for (final liftBundle in lifts) ...[
                _LiftCard(
                  liftBundle: liftBundle,
                  onSaveSet: _saveSet,
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              _WorkoutTotalsFooter(
                workoutScore: workoutScore,
                totalWorkload: totalWorkload,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _finishWorkout,
                  child: const Text('Finish Workout'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkoutHeaderCard extends StatelessWidget {
  final String blockTitle;
  final String workoutTitle;
  final String runNumber;
  final String dayLabel;

  const _WorkoutHeaderCard({
    required this.blockTitle,
    required this.workoutTitle,
    required this.runNumber,
    required this.dayLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    blockTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    workoutTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text('Run $runNumber'),
                  if (dayLabel.isNotEmpty) Text(dayLabel),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutTotalsFooter extends StatelessWidget {
  final double workoutScore;
  final double totalWorkload;

  const _WorkoutTotalsFooter({
    required this.workoutScore,
    required this.totalWorkload,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Workout Score: ${workoutScore.toStringAsFixed(2)}',
              ),
            ),
            Expanded(
              child: Text(
                'Total Workload: ${totalWorkload.toStringAsFixed(0)}',
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiftCard extends StatefulWidget {
  final Map<String, Object?> liftBundle;
  final Future<void> Function({
  required int liftInstanceId,
  required int setIndex,
  required int reps,
  required double? weight,
  }) onSaveSet;

  const _LiftCard({
    required this.liftBundle,
    required this.onSaveSet,
  });

  @override
  State<_LiftCard> createState() => _LiftCardState();
}

class _LiftCardState extends State<_LiftCard> {
  late final List<TextEditingController> _repsControllers;
  late final List<TextEditingController> _weightControllers;
  late final List<FocusNode> _repsFocusNodes;
  late final List<FocusNode> _weightFocusNodes;
  late final List<int?> _lastSavedReps;
  late final List<double?> _lastSavedWeight;
  bool _isAutoSaving = false;

  int _parseSetCount(String repScheme) {
    final parts = repScheme.toLowerCase().split('x');
    if (parts.length != 2) return 4;

    final sets = int.tryParse(parts[0].trim());
    return sets ?? 4;
  }

  @override
  void initState() {
    super.initState();

    final liftInstance =
    widget.liftBundle['lift_instance'] as Map<String, Object?>;
    final logs = widget.liftBundle['logs'] as List<Map<String, Object?>>;
    final repScheme =
        (liftInstance['rep_scheme_snapshot'] as String?) ?? '';

    final setCount = _parseSetCount(repScheme);

    _repsControllers = List.generate(setCount, (index) {
      final log = index < logs.length ? logs[index] : null;
      return TextEditingController(
        text: log?['reps']?.toString() ?? '',
      );
    });

    _weightControllers = List.generate(setCount, (index) {
      final log = index < logs.length ? logs[index] : null;
      return TextEditingController(
        text: log?['weight']?.toString() ?? '',
      );
    });

    _lastSavedReps = List.generate(setCount, (index) {
      final log = index < logs.length ? logs[index] : null;
      return log?['reps'] as int?;
    });

    _lastSavedWeight = List.generate(setCount, (index) {
      final log = index < logs.length ? logs[index] : null;
      return (log?['weight'] as num?)?.toDouble();
    });

    _repsFocusNodes = List.generate(setCount, (index) {
      final node = FocusNode();
      node.addListener(() => _handleFieldBlur(index: index));
      return node;
    });

    _weightFocusNodes = List.generate(setCount, (index) {
      final node = FocusNode();
      node.addListener(() => _handleFieldBlur(index: index));
      return node;
    });
  }

  @override
  void dispose() {
    for (final controller in _repsControllers) {
      controller.dispose();
    }
    for (final controller in _weightControllers) {
      controller.dispose();
    }
    for (final node in _repsFocusNodes) {
      node.dispose();
    }
    for (final node in _weightFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _handleFieldBlur({required int index}) async {
    final repsNodeHasFocus = _repsFocusNodes[index].hasFocus;
    final weightNodeHasFocus = _weightFocusNodes[index].hasFocus;

    if (repsNodeHasFocus || weightNodeHasFocus) {
      return;
    }

    await _autoSaveSet(index: index);
  }

  Future<void> _autoSaveSet({required int index}) async {
    if (_isAutoSaving) return;

    final liftInstance =
        widget.liftBundle['lift_instance'] as Map<String, Object?>;
    final liftInstanceId = liftInstance['id'] as int;
    final scoreType = (liftInstance['score_type_snapshot'] as String?) ?? '';
    final isBodyweight = scoreType == 'bodyweight';

    final repsText = _repsControllers[index].text.trim();
    final weightText = _weightControllers[index].text.trim();

    final reps = repsText.isEmpty ? null : int.tryParse(repsText);
    final weight = weightText.isEmpty ? null : double.tryParse(weightText);

    if (reps == null) {
      return;
    }

    if (!isBodyweight && weight == null) {
      return;
    }

    final lastReps = _lastSavedReps[index];
    final lastWeight = _lastSavedWeight[index];
    final hasRepsChanged = lastReps != reps;
    final hasWeightChanged =
        (weight ?? 0).toStringAsFixed(4) != (lastWeight ?? 0).toStringAsFixed(4) ||
            (weight == null) != (lastWeight == null);

    if (!hasRepsChanged && !hasWeightChanged) {
      return;
    }

    _isAutoSaving = true;
    try {
      await widget.onSaveSet(
        liftInstanceId: liftInstanceId,
        setIndex: index,
        reps: reps,
        weight: weight,
      );
      _lastSavedReps[index] = reps;
      _lastSavedWeight[index] = weight;
    } finally {
      _isAutoSaving = false;
    }
  }

  TableCell _cell({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(8),
    Color? color,
    double? height,
    Alignment alignment = Alignment.center,
  }) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Container(
        alignment: alignment,
        padding: padding,
        color: color,
        height: height,
        child: child,
      ),
    );
  }

  TableRow _buildHeaderRow(bool showsRecommended) {
    return TableRow(
      children: [
        _cell(child: const Text('')),
        _cell(
          child: const Text(
            'Reps',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
        ),
        _cell(child: const Text('X')),
        _cell(
          child: const Text(
            'Weight',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
        ),
        _cell(
          child: const SizedBox.shrink(),
          color: Colors.black12,
          height: 40,
          padding: EdgeInsets.zero,
        ),
        _cell(
          child: const Text(
            'Prev Reps',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
        ),
        _cell(child: const Text('X')),
        _cell(
          child: Text(
            showsRecommended ? 'Recommended' : 'Prev Weight',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  String _getPreviousRepsText(
      List<Map<String, Object?>> previousLogs,
      int index,
      ) {
    if (index >= previousLogs.length) return '-';
    final reps = previousLogs[index]['reps'];
    return reps?.toString() ?? '-';
  }

  String _getPreviousWeightText(
      List<Map<String, Object?>> previousLogs,
      int index,
      ) {
    if (index >= previousLogs.length) return '-';

    final weight = (previousLogs[index]['weight'] as num?)?.toDouble();
    if (weight == null) return '-';

    return weight % 1 == 0
        ? weight.toStringAsFixed(0)
        : weight.toStringAsFixed(1);
  }

  TableRow _buildSetRow({
    required int index,
    required String prevRepsText,
    required String rightSideText,
    required bool showsRecommended,
  }) {
    return TableRow(
      children: [
        _cell(
          child: Text(
            'Set ${index + 1}',
            textAlign: TextAlign.center,
          ),
        ),
        _cell(
          color: const Color(0xFFEFEFEF),
          child: TextField(
            controller: _repsControllers[index],
            focusNode: _repsFocusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
        _cell(child: const Text('X')),
        _cell(
          color: const Color(0xFFEFEFEF),
          child: TextField(
            controller: _weightControllers[index],
            focusNode: _weightFocusNodes[index],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
        _cell(
          child: const SizedBox.shrink(),
          color: Colors.black12,
          height: 40,
          padding: EdgeInsets.zero,
        ),
        _cell(
          child: Text(
            prevRepsText,
            textAlign: TextAlign.center,
          ),
        ),
        _cell(child: const Text('X')),
        _cell(
          child: Text(
            rightSideText,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: showsRecommended ? Colors.red : null,
              fontWeight: showsRecommended ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  TableRow _buildTotalsRow({
    required int totalReps,
    required double totalWorkload,
    required int previousTotalReps,
    required double previousTotalWorkload,
  }) {
    return TableRow(
      children: [
        _cell(
          child: const Text(
            'Total',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        _cell(
          color: Colors.grey.shade300,
          child: Text(
            totalReps.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        _cell(child: const Text('')),
        _cell(
          color: Colors.grey.shade300,
          child: Text(
            totalWorkload.toStringAsFixed(0),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        _cell(
          child: const SizedBox.shrink(),
          color: Colors.black12,
          height: 40,
          padding: EdgeInsets.zero,
        ),
        _cell(
          child: Text(
            previousTotalReps.toString(),
            textAlign: TextAlign.center,
          ),
        ),
        _cell(child: const Text('')),
        _cell(
          child: Text(
            previousTotalWorkload.toStringAsFixed(0),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  TableRow _buildScoreRow({
    required double totalScore,
    required double previousTotalScore,
  }) {
    return TableRow(
      children: [
        _cell(child: const Text('')),
        _cell(
          child: const Text(
            'Score',
            textAlign: TextAlign.center,
          ),
        ),
        _cell(child: const Text('')),
        _cell(
          color: Colors.blue.shade700,
          child: Text(
            totalScore.toStringAsFixed(2),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
        ),
        _cell(
          child: const SizedBox.shrink(),
          color: Colors.black12,
          height: 40,
          padding: EdgeInsets.zero,
        ),
        _cell(
          child: Text(
            '-',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
        _cell(child: const Text('')),
        _cell(
          color: Colors.blue.shade900,
          child: Text(
            previousTotalScore.toStringAsFixed(2),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final liftInstance =
    widget.liftBundle['lift_instance'] as Map<String, Object?>;
    final totals = widget.liftBundle['totals'] as Map<String, Object?>;
    final previous = widget.liftBundle['previous'] as Map<String, Object?>;
    final previousLogs = previous['logs'] as List<Map<String, Object?>>;
    final liftName =
        (liftInstance['lift_name_snapshot'] as String?) ?? 'Lift';
    final repScheme =
        (liftInstance['rep_scheme_snapshot'] as String?) ?? '';
    final liftInfo =
        (liftInstance['lift_info_snapshot'] as String?) ?? '';
    final totalReps = (totals['total_reps'] as int?) ?? 0;
    final totalWorkload =
    ((totals['total_workload'] as num?) ?? 0).toDouble();
    final totalScore =
    ((totals['total_score'] as num?) ?? 0).toDouble();

    final previousTotalReps = (previous['total_reps'] as int?) ?? 0;
    final previousTotalWorkload =
    ((previous['total_workload'] as num?) ?? 0).toDouble();
    final previousTotalScore =
    ((previous['total_score'] as num?) ?? 0).toDouble();

    final recommendedWeight =
    widget.liftBundle['recommended_weight'] as double?;

    final showsRecommended = recommendedWeight != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            GestureDetector(
              onTap: () {},
              child: Text(
                liftName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(repScheme),
            if (liftInfo.isNotEmpty) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  liftInfo,
                  textAlign: TextAlign.left,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.05),
                1: FlexColumnWidth(1.0),
                2: FlexColumnWidth(0.32),
                3: FlexColumnWidth(1.15),
                4: FlexColumnWidth(0.10),
                5: FlexColumnWidth(1.0),
                6: FlexColumnWidth(0.32),
                7: FlexColumnWidth(1.15),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                _buildHeaderRow(showsRecommended),
                ...List.generate(
                  _repsControllers.length,
                      (index) => _buildSetRow(
                    index: index,
                    prevRepsText: _getPreviousRepsText(previousLogs, index),
                    rightSideText: showsRecommended
                        ? recommendedWeight!.toStringAsFixed(0)
                        : _getPreviousWeightText(previousLogs, index),
                    showsRecommended: showsRecommended,
                  ),
                ),
                _buildTotalsRow(
                  totalReps: totalReps,
                  totalWorkload: totalWorkload,
                  previousTotalReps: previousTotalReps,
                  previousTotalWorkload: previousTotalWorkload,
                ),
                _buildScoreRow(
                  totalScore: totalScore,
                  previousTotalScore: previousTotalScore,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
