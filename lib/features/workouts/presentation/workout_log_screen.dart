import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../data/local/services/badge_evaluation_service.dart';
import '../../../data/local/services/lift_logging_service.dart';
import '../../../data/local/services/workout_completion_service.dart';
import '../../../data/local/services/workout_query_service.dart';
import '../../blocks/presentation/block_summary_screen.dart';
import 'widgets/badge_award_dialog.dart';
import 'widgets/workout_keypad.dart';

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
  _KeypadBinding? _activeKeypadBinding;

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
      await _syncTotalsAfterSetSave(liftInstanceId: liftInstanceId);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _syncTotalsAfterSetSave({
    required int liftInstanceId,
  }) async {
    final currentData = _workoutData;
    if (currentData == null) return;

    final updatedLiftTotals = await WorkoutQueryService.instance.getLiftTotals(
      liftInstanceId: liftInstanceId,
    );
    final updatedWorkoutTotals =
        await WorkoutQueryService.instance.getWorkoutTotals(
      workoutInstanceId: widget.workoutInstanceId,
    );

    if (!mounted) return;

    final existingLifts =
        List<Map<String, Object?>>.from(currentData['lifts'] as List);
    final liftBundleIndex = existingLifts.indexWhere((liftBundle) {
      final liftInstance =
          liftBundle['lift_instance'] as Map<String, Object?>;
      final id = liftInstance['id'] as int?;
      return id == liftInstanceId;
    });

    if (liftBundleIndex == -1) {
      setState(() {
        _workoutData = {
          ...currentData,
          'workout_totals': updatedWorkoutTotals,
        };
      });
      return;
    }

    final updatedLiftBundle =
        Map<String, Object?>.from(existingLifts[liftBundleIndex]);
    updatedLiftBundle['totals'] = updatedLiftTotals;
    existingLifts[liftBundleIndex] = updatedLiftBundle;

    setState(() {
      _workoutData = {
        ...currentData,
        'lifts': existingLifts,
        'workout_totals': updatedWorkoutTotals,
      };
    });
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
        if (decoded is Map) {
          final metadata = Map<String, dynamic>.from(decoded);
          liftKey = metadata['lift_key'] as String?;
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
        if (decoded is Map) {
          final metadata = Map<String, dynamic>.from(decoded);
          final rawThreshold = metadata['threshold_lbs'];

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
    final previousWorkoutTotals =
        _workoutData!['previous_workout_totals'] as Map<String, Object?>? ?? {};

    final blockTitle =
        (workout['block_title_snapshot'] as String?) ?? 'Block';
    final workoutTitle = (workout['title_snapshot'] as String?) ?? 'Workout';
    final workoutScore =
    ((workoutTotals['workout_score'] as num?) ?? 0).toDouble();
    final previousWorkoutScore =
        ((previousWorkoutTotals['workout_score'] as num?) ?? 0).toDouble();
    final totalWorkload =
    ((workoutTotals['total_workload'] as num?) ?? 0).toDouble();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('$blockTitle - $workoutTitle'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: _WorkoutTotalsFooter(
        workoutScore: workoutScore,
        previousWorkoutScore: previousWorkoutScore,
        totalWorkload: totalWorkload,
      ),
      body: RefreshIndicator(
          onRefresh: _loadWorkout,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              12,
              12,
              12,
              _activeKeypadBinding == null ? 20 : 240,
            ),
            children: [
              for (var index = 0; index < lifts.length; index++) ...[
                _LiftCard(
                  liftBundle: lifts[index],
                  onSaveSet: _saveSet,
                  onActiveFieldChanged: _handleActiveFieldChanged,
                ),
                if (index < lifts.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(
                      color: Colors.white24,
                      thickness: 0.5,
                      height: 1,
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              Center(
                child: SizedBox(
                  height: 44,
                  width: 220,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _finishWorkout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F1F1F),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text('Finish Workout'),
                  ),
                ),
              ),
            ],
          ),
        ),
      bottomSheet: _activeKeypadBinding == null
          ? null
          : WorkoutKeypad(
              onNumberTap: _activeKeypadBinding!.onInput,
              onBackspace: _activeKeypadBinding!.onBackspace,
              onDone: _activeKeypadBinding!.onDone,
              onMoveRight: _activeKeypadBinding!.onMoveRight,
              onMoveDown: _activeKeypadBinding!.onMoveDown,
              onFillDown: _activeKeypadBinding!.onFillDown,
            ),
    );
  }

  void _handleActiveFieldChanged(_KeypadBinding? binding) {
    if (!mounted) return;
    if (_activeKeypadBinding == binding) return;
    setState(() {
      _activeKeypadBinding = binding;
    });
  }
}

class _KeypadBinding {
  final ValueChanged<String> onInput;
  final VoidCallback onBackspace;
  final VoidCallback onDone;
  final VoidCallback onMoveRight;
  final VoidCallback onMoveDown;
  final VoidCallback onFillDown;

  const _KeypadBinding({
    required this.onInput,
    required this.onBackspace,
    required this.onDone,
    required this.onMoveRight,
    required this.onMoveDown,
    required this.onFillDown,
  });
}

enum _EditableColumn { reps, weight }

class _WorkoutTotalsFooter extends StatelessWidget {
  final double workoutScore;
  final double previousWorkoutScore;
  final double totalWorkload;

  const _WorkoutTotalsFooter({
    required this.workoutScore,
    required this.previousWorkoutScore,
    required this.totalWorkload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.white, fontSize: 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Workout Score: ${workoutScore.toStringAsFixed(1)}'),
                    Text(
                      'Previous Score: ${previousWorkoutScore.toStringAsFixed(1)}',
                    ),
                    Text('Total Workload: ${totalWorkload.toStringAsFixed(1)} lbs'),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            const _RestTimer(),
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
  final ValueChanged<_KeypadBinding?> onActiveFieldChanged;

  const _LiftCard({
    required this.liftBundle,
    required this.onSaveSet,
    required this.onActiveFieldChanged,
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
  int? _activeSetIndex;
  _EditableColumn? _activeColumn;

  int _parseSetCount(String repScheme) {
    final parts = repScheme.toLowerCase().split('x');
    if (parts.length != 2) return 4;

    final sets = int.tryParse(parts[0].trim());
    return sets ?? 4;
  }

  String _displayRepScheme(String repScheme) {
    final parts = repScheme.toLowerCase().split('x');
    if (parts.length != 2) return repScheme;

    final sets = int.tryParse(parts[0].trim());
    final reps = int.tryParse(parts[1].trim());
    if (sets == null || reps == null) return repScheme;
    return '$sets Sets x $reps Reps';
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
      node.addListener(() => _handleFocusChange(index: index));
      return node;
    });

    _weightFocusNodes = List.generate(setCount, (index) {
      final node = FocusNode();
      node.addListener(() => _handleFocusChange(index: index));
      return node;
    });
  }

  @override
  void dispose() {
    widget.onActiveFieldChanged(null);
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

  void _handleFocusChange({required int index}) {
    unawaited(_handleFieldBlur(index: index));
    _updateActiveFieldBinding();
  }

  void _updateActiveFieldBinding() {
    for (var i = 0; i < _repsFocusNodes.length; i++) {
      if (_repsFocusNodes[i].hasFocus) {
        _activeSetIndex = i;
        _activeColumn = _EditableColumn.reps;
        widget.onActiveFieldChanged(
          _KeypadBinding(
            onInput: _handleKeypadInput,
            onBackspace: _handleBackspace,
            onDone: _handleDone,
            onMoveRight: _moveRight,
            onMoveDown: _moveDown,
            onFillDown: () => unawaited(_fillDown()),
          ),
        );
        return;
      }
      if (_weightFocusNodes[i].hasFocus) {
        _activeSetIndex = i;
        _activeColumn = _EditableColumn.weight;
        widget.onActiveFieldChanged(
          _KeypadBinding(
            onInput: _handleKeypadInput,
            onBackspace: _handleBackspace,
            onDone: _handleDone,
            onMoveRight: _moveRight,
            onMoveDown: _moveDown,
            onFillDown: () => unawaited(_fillDown()),
          ),
        );
        return;
      }
    }

    _activeSetIndex = null;
    _activeColumn = null;
    widget.onActiveFieldChanged(null);
  }

  TextEditingController? _activeController() {
    final setIndex = _activeSetIndex;
    final column = _activeColumn;
    if (setIndex == null || column == null) return null;

    return column == _EditableColumn.reps
        ? _repsControllers[setIndex]
        : _weightControllers[setIndex];
  }

  void _handleKeypadInput(String value) {
    final controller = _activeController();
    if (controller == null) return;
    if (value == '.' && controller.text.contains('.')) return;
    controller.text += value;
  }

  void _handleBackspace() {
    final controller = _activeController();
    if (controller == null || controller.text.isEmpty) return;
    controller.text = controller.text.substring(0, controller.text.length - 1);
  }

  void _handleDone() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _moveRight() {
    final setIndex = _activeSetIndex;
    if (setIndex == null) return;
    if (_activeColumn != _EditableColumn.reps) return;
    _weightFocusNodes[setIndex].requestFocus();
  }

  void _moveDown() {
    final setIndex = _activeSetIndex;
    final column = _activeColumn;
    if (setIndex == null || column == null) return;
    if (setIndex >= _repsControllers.length - 1) return;

    if (column == _EditableColumn.reps) {
      _repsFocusNodes[setIndex + 1].requestFocus();
    } else {
      _weightFocusNodes[setIndex + 1].requestFocus();
    }
  }

  Future<void> _fillDown() async {
    final controller = _activeController();
    final column = _activeColumn;
    if (controller == null || column == null) return;

    final value = controller.text;
    final targetControllers =
    column == _EditableColumn.reps ? _repsControllers : _weightControllers;

    for (final target in targetControllers) {
      target.text = value;
    }

    for (var i = 0; i < targetControllers.length; i++) {
      await _autoSaveSet(index: i);
    }
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
        _cell(
          child: const Text(
            'Set',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        _cell(
          child: const Text(
            'Reps',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        _cell(child: const Text('X', style: TextStyle(color: Colors.white))),
        _cell(
          child: const Text(
            'Weight',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        _cell(
          child: const SizedBox.shrink(),
          color: Colors.black,
          height: 40,
          padding: EdgeInsets.zero,
        ),
        _cell(
          child: const Text(
            'Prev Reps',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        _cell(child: const Text('X', style: TextStyle(color: Colors.white))),
        _cell(
          child: Text(
            showsRecommended ? 'Recommended' : 'Prev Weight',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 12),
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
            style: const TextStyle(color: Colors.white),
          ),
        ),
        _cell(
          color: const Color(0xFF2E4F40),
          child: TextField(
            controller: _repsControllers[index],
            focusNode: _repsFocusNodes[index],
            readOnly: true,
            showCursor: true,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
              isDense: true,
            ),
          ),
        ),
        _cell(child: const Text('X', style: TextStyle(color: Colors.white))),
        _cell(
          color: const Color(0xFF2E4F40),
          child: TextField(
            controller: _weightControllers[index],
            focusNode: _weightFocusNodes[index],
            readOnly: true,
            showCursor: true,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
              isDense: true,
            ),
          ),
        ),
        _cell(
          child: const SizedBox.shrink(),
          color: Colors.black,
          height: 40,
          padding: EdgeInsets.zero,
        ),
        _cell(
          child: Text(
            prevRepsText,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        _cell(child: const Text('X', style: TextStyle(color: Colors.white70))),
        _cell(
          child: Text(
            rightSideText,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: showsRecommended ? Colors.redAccent : Colors.white70,
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
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        _cell(
          color: const Color(0xFF3A3A3A),
          child: Text(
            totalReps.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
        _cell(child: const Text('', style: TextStyle(color: Colors.white))),
        _cell(
          color: const Color(0xFF3A3A3A),
          child: Text(
            totalWorkload.toStringAsFixed(0),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
        _cell(
          child: const SizedBox.shrink(),
          color: Colors.black,
          height: 40,
          padding: EdgeInsets.zero,
        ),
        _cell(
          child: Text(
            previousTotalReps.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        _cell(child: const Text('', style: TextStyle(color: Colors.white70))),
        _cell(
          child: Text(
            previousTotalWorkload.toStringAsFixed(0),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
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
        _cell(child: const Text('', style: TextStyle(color: Colors.white))),
        _cell(
          child: const Text(
            'Score',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
        ),
        _cell(child: const Text('', style: TextStyle(color: Colors.white))),
        _cell(
          color: const Color(0xFF1565C0),
          child: Text(
            totalScore.toStringAsFixed(1),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
        ),
        _cell(
          child: const SizedBox.shrink(),
          color: Colors.black,
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
        _cell(child: const Text('', style: TextStyle(color: Colors.white70))),
        _cell(
          color: const Color(0xFF0D47A1),
          child: Text(
            previousTotalScore.toStringAsFixed(1),
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
      color: Colors.black,
      margin: EdgeInsets.zero,
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
            Text(
              _displayRepScheme(repScheme),
              style: const TextStyle(color: Colors.white),
            ),
            if (liftInfo.isNotEmpty) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  liftInfo,
                  textAlign: TextAlign.left,
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
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
              border: const TableBorder(
                horizontalInside: BorderSide(color: Colors.white12, width: 0.5),
              ),
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

class _RestTimer extends StatefulWidget {
  const _RestTimer();

  @override
  State<_RestTimer> createState() => _RestTimerState();
}

class _RestTimerState extends State<_RestTimer> {
  static const List<int> _presets = [30, 60, 90, 120];
  Timer? _timer;
  int _secondsRemaining = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() {
      _secondsRemaining = seconds;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining == 0) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsRemaining -= 1;
      });
    });
  }

  String get _display {
    final minutes = _secondsRemaining ~/ 60;
    final seconds = _secondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isZero = _secondsRemaining == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _display,
              style: TextStyle(
                color: isZero ? Colors.red : Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              onPressed: () => _startTimer(_secondsRemaining == 0 ? 60 : _secondsRemaining),
              icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(2),
              constraints: const BoxConstraints(),
              tooltip: 'Restart',
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          children: _presets
              .map(
                (seconds) => OutlinedButton(
                  onPressed: () => _startTimer(seconds),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    seconds >= 120 ? '2m' : '${seconds}s',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
