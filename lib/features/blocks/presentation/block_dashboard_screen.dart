import 'package:flutter/material.dart';

import '../../../data/local/services/block_query_service.dart';
import '../../workouts/presentation/workout_log_screen.dart';

class BlockDashboardScreen extends StatefulWidget {
  final int blockInstanceId;

  const BlockDashboardScreen({
    super.key,
    required this.blockInstanceId,
  });

  @override
  State<BlockDashboardScreen> createState() => _BlockDashboardScreenState();
}

class _BlockDashboardScreenState extends State<BlockDashboardScreen> {
  bool _isLoading = true;
  Map<String, Object?>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBlock();
  }

  Future<void> _loadBlock() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await BlockQueryService.instance.getBlockDashboardData(
        blockInstanceId: widget.blockInstanceId,
      );

      if (!mounted) return;

      setState(() {
        _data = data;
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

  Future<void> _openWorkout(int workoutInstanceId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutLogScreen(
          workoutInstanceId: workoutInstanceId,
        ),
      ),
    );

    await _loadBlock();
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
        appBar: AppBar(title: const Text('Block Dashboard')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_error!),
          ),
        ),
      );
    }

    final block = _data!['block'] as Map<String, Object?>;
    final workouts = _data!['workouts'] as List<Map<String, Object?>>;
    final blockTotals = _data!['block_totals'] as Map<String, Object?>;

    final title = (block['title_snapshot'] as String?) ?? 'Block';
    final category = (block['category'] as String?) ?? '';
    final runNumber = block['run_number']?.toString() ?? '-';
    final blockScore = ((blockTotals['block_score'] as num?) ?? 0).toDouble();
    final totalWorkload =
    ((blockTotals['total_workload'] as num?) ?? 0).toDouble();
    final completedWorkoutCount =
        (blockTotals['completed_workout_count'] as int?) ?? 0;
    final totalWorkoutCount =
        (blockTotals['total_workout_count'] as int?) ?? 0;
    final trainingDays = (blockTotals['training_days'] as int?) ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('$title (Run $runNumber)'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadBlock,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _BlockHeaderCard(
              title: title,
              category: category,
              runNumber: runNumber,
            ),
            const SizedBox(height: 12),
            _BlockTotalsCard(
              blockScore: blockScore,
              totalWorkload: totalWorkload,
              completedWorkoutCount: completedWorkoutCount,
              totalWorkoutCount: totalWorkoutCount,
              trainingDays: trainingDays,
            ),
            const SizedBox(height: 12),
            for (final workout in workouts) ...[
              _WorkoutListCard(
                workout: workout,
                onTap: () => _openWorkout(workout['id'] as int),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _BlockHeaderCard extends StatelessWidget {
  final String title;
  final String category;
  final String runNumber;

  const _BlockHeaderCard({
    required this.title,
    required this.category,
    required this.runNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            if (category.isNotEmpty) Text(category),
            const SizedBox(height: 4),
            Text('Run $runNumber'),
          ],
        ),
      ),
    );
  }
}

class _BlockTotalsCard extends StatelessWidget {
  final double blockScore;
  final double totalWorkload;
  final int completedWorkoutCount;
  final int totalWorkoutCount;
  final int trainingDays;

  const _BlockTotalsCard({
    required this.blockScore,
    required this.totalWorkload,
    required this.completedWorkoutCount,
    required this.totalWorkoutCount,
    required this.trainingDays,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Block Score: ${blockScore.toStringAsFixed(2)}'),
                ),
                Expanded(
                  child: Text(
                    'Workload: ${totalWorkload.toStringAsFixed(0)}',
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Workouts: $completedWorkoutCount / $totalWorkoutCount',
                  ),
                ),
                Expanded(
                  child: Text(
                    'Days: $trainingDays',
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutListCard extends StatelessWidget {
  final Map<String, Object?> workout;
  final VoidCallback onTap;

  const _WorkoutListCard({
    required this.workout,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = (workout['title_snapshot'] as String?) ?? 'Workout';
    final dayLabel = (workout['day_label'] as String?) ?? '';
    final status = (workout['status'] as String?) ?? 'not_started';
    final workoutScore = ((workout['workout_score'] as num?) ?? 0).toDouble();
    final totalWorkload =
    ((workout['total_workload'] as num?) ?? 0).toDouble();
    final completedLiftCount =
        (workout['completed_lift_count'] as int?) ?? 0;
    final totalLiftCount = (workout['total_lift_count'] as int?) ?? 0;

    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dayLabel.isNotEmpty) Text(dayLabel),
            Text(
              'Status: $status • Lifts: $completedLiftCount / $totalLiftCount',
            ),
            Text(
              'Score: ${workoutScore.toStringAsFixed(2)} • Workload: ${totalWorkload.toStringAsFixed(0)}',
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}