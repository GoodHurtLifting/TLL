import 'package:flutter/material.dart';

import '../../../data/local/services/block_summary_query_service.dart';

class BlockSummaryScreen extends StatefulWidget {
  final int blockInstanceId;

  const BlockSummaryScreen({
    super.key,
    required this.blockInstanceId,
  });

  @override
  State<BlockSummaryScreen> createState() => _BlockSummaryScreenState();
}

class _BlockSummaryScreenState extends State<BlockSummaryScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, Object?>? _data;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await BlockSummaryQueryService.instance.getBlockSummaryData(
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Block Summary')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_error!),
          ),
        ),
      );
    }

    final block = _data!['block'] as Map<String, Object?>;
    final blockTotals = _data!['block_totals'] as Map<String, Object?>;
    final workouts = _data!['workouts'] as List<Map<String, Object?>>;

    final blockTitle = (block['title_snapshot'] as String?) ?? 'Block';
    final category = (block['category'] as String?) ?? '';
    final runNumber = block['run_number']?.toString() ?? '-';

    final totalWorkload =
    ((blockTotals['total_workload'] as num?) ?? 0).toDouble();
    final blockScore =
    ((blockTotals['block_score'] as num?) ?? 0).toDouble();
    final completedWorkoutCount =
        (blockTotals['completed_workout_count'] as int?) ?? 0;
    final totalWorkoutCount =
        (blockTotals['total_workout_count'] as int?) ?? 0;
    final trainingDays = (blockTotals['training_days'] as int?) ?? 0;

    final completionRate = totalWorkoutCount == 0
        ? 0.0
        : (completedWorkoutCount / totalWorkoutCount) * 100;

    final bestWorkout = _getBestWorkout(workouts);
    final highestWorkloadWorkout = _getHighestWorkloadWorkout(workouts);
    final averageWorkoutScore = completedWorkoutCount == 0
        ? 0.0
        : workouts.fold<double>(
      0.0,
          (sum, workout) =>
      sum + (((workout['workout_score'] as num?) ?? 0).toDouble()),
    ) /
        totalWorkoutCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Block Summary'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadSummary,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SummaryHeaderCard(
              blockTitle: blockTitle,
              category: category,
              runNumber: runNumber,
            ),
            const SizedBox(height: 12),
            _OverviewCard(
              totalWorkload: totalWorkload,
              blockScore: blockScore,
              completedWorkoutCount: completedWorkoutCount,
              totalWorkoutCount: totalWorkoutCount,
              trainingDays: trainingDays,
            ),
            const SizedBox(height: 12),
            _PlanAdherenceCard(
              completionRate: completionRate,
              completedWorkoutCount: completedWorkoutCount,
              totalWorkoutCount: totalWorkoutCount,
              trainingDays: trainingDays,
            ),
            const SizedBox(height: 12),
            _ImprovementCard(
              bestWorkoutTitle: bestWorkout['title'] as String? ?? '-',
              bestWorkoutScore:
              ((bestWorkout['score'] as num?) ?? 0).toDouble(),
              highestWorkloadTitle:
              highestWorkloadWorkout['title'] as String? ?? '-',
              highestWorkoutWorkload:
              ((highestWorkloadWorkout['workload'] as num?) ?? 0)
                  .toDouble(),
              averageWorkoutScore: averageWorkoutScore,
            ),
            const SizedBox(height: 12),
            const _MilestonesCard(),
            const SizedBox(height: 16),
            Text(
              'Workout Details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final workout in workouts) ...[
              _SummaryWorkoutCard(workout: workout),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  Map<String, Object?> _getBestWorkout(List<Map<String, Object?>> workouts) {
    if (workouts.isEmpty) {
      return {
        'title': '-',
        'score': 0.0,
      };
    }

    Map<String, Object?> best = workouts.first;
    double bestScore = ((best['workout_score'] as num?) ?? 0).toDouble();

    for (final workout in workouts.skip(1)) {
      final score = ((workout['workout_score'] as num?) ?? 0).toDouble();
      if (score > bestScore) {
        best = workout;
        bestScore = score;
      }
    }

    return {
      'title': best['title_snapshot'] as String? ?? '-',
      'score': bestScore,
    };
  }

  Map<String, Object?> _getHighestWorkloadWorkout(
      List<Map<String, Object?>> workouts,
      ) {
    if (workouts.isEmpty) {
      return {
        'title': '-',
        'workload': 0.0,
      };
    }

    Map<String, Object?> best = workouts.first;
    double bestWorkload =
    ((best['total_workload'] as num?) ?? 0).toDouble();

    for (final workout in workouts.skip(1)) {
      final workload =
      ((workout['total_workload'] as num?) ?? 0).toDouble();
      if (workload > bestWorkload) {
        best = workout;
        bestWorkload = workload;
      }
    }

    return {
      'title': best['title_snapshot'] as String? ?? '-',
      'workload': bestWorkload,
    };
  }
}

class _SummaryHeaderCard extends StatelessWidget {
  final String blockTitle;
  final String category;
  final String runNumber;

  const _SummaryHeaderCard({
    required this.blockTitle,
    required this.category,
    required this.runNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              blockTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            const Text('Summary'),
            const SizedBox(height: 6),
            if (category.isNotEmpty) Text(category),
            Text('Run $runNumber'),
          ],
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final double totalWorkload;
  final double blockScore;
  final int completedWorkoutCount;
  final int totalWorkoutCount;
  final int trainingDays;

  const _OverviewCard({
    required this.totalWorkload,
    required this.blockScore,
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
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Overview',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Block Score',
                    value: blockScore.toStringAsFixed(2),
                  ),
                ),
                Expanded(
                  child: _StatTile(
                    label: 'Total Workload',
                    value: totalWorkload.toStringAsFixed(0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Workouts',
                    value: '$completedWorkoutCount / $totalWorkoutCount',
                  ),
                ),
                Expanded(
                  child: _StatTile(
                    label: 'Days Taken',
                    value: trainingDays.toString(),
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

class _PlanAdherenceCard extends StatelessWidget {
  final double completionRate;
  final int completedWorkoutCount;
  final int totalWorkoutCount;
  final int trainingDays;

  const _PlanAdherenceCard({
    required this.completionRate,
    required this.completedWorkoutCount,
    required this.totalWorkoutCount,
    required this.trainingDays,
  });

  @override
  Widget build(BuildContext context) {
    final adherenceLabel = completionRate >= 100
        ? 'Completed the plan'
        : completionRate >= 75
        ? 'Mostly on plan'
        : completionRate >= 40
        ? 'Partial completion'
        : 'Early in the run';

    final averageWorkoutsPerDay = trainingDays == 0
        ? 0.0
        : completedWorkoutCount / trainingDays;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Plan Adherence',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Completion Rate',
                    value: '${completionRate.toStringAsFixed(0)}%',
                  ),
                ),
                Expanded(
                  child: _StatTile(
                    label: 'Session Pace',
                    value: averageWorkoutsPerDay.toStringAsFixed(2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(adherenceLabel),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Completed $completedWorkoutCount of $totalWorkoutCount scheduled workouts in $trainingDays training days.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImprovementCard extends StatelessWidget {
  final String bestWorkoutTitle;
  final double bestWorkoutScore;
  final String highestWorkloadTitle;
  final double highestWorkoutWorkload;
  final double averageWorkoutScore;

  const _ImprovementCard({
    required this.bestWorkoutTitle,
    required this.bestWorkoutScore,
    required this.highestWorkloadTitle,
    required this.highestWorkoutWorkload,
    required this.averageWorkoutScore,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Improvements',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              label: 'Best Workout',
              value: '$bestWorkoutTitle (${bestWorkoutScore.toStringAsFixed(2)})',
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: 'Highest Workload',
              value:
              '$highestWorkloadTitle (${highestWorkoutWorkload.toStringAsFixed(0)})',
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: 'Average Workout Score',
              value: averageWorkoutScore.toStringAsFixed(2),
            ),
          ],
        ),
      ),
    );
  }
}

class _MilestonesCard extends StatelessWidget {
  const _MilestonesCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Milestones & Badges',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Badge tracking and milestone callouts will appear here.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryWorkoutCard extends StatelessWidget {
  final Map<String, Object?> workout;

  const _SummaryWorkoutCard({
    required this.workout,
  });

  @override
  Widget build(BuildContext context) {
    final title = (workout['title_snapshot'] as String?) ?? 'Workout';
    final dayLabel = (workout['day_label'] as String?) ?? '';
    final status = (workout['status'] as String?) ?? 'not_started';
    final workload =
    ((workout['total_workload'] as num?) ?? 0).toDouble();
    final score = ((workout['workout_score'] as num?) ?? 0).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  if (dayLabel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      dayLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Status: $status',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Score: ${score.toStringAsFixed(2)}'),
                const SizedBox(height: 4),
                Text('Workload: ${workload.toStringAsFixed(0)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}