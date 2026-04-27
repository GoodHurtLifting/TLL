import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../data/local/badges/badge_definitions.dart';
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
  static const Color _screenBackground = Colors.black;
  static const Color _primaryText = Colors.white;

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
        backgroundColor: _screenBackground,
        appBar: AppBar(title: const Text('Block Summary')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _error!,
              style: const TextStyle(color: _primaryText),
            ),
          ),
        ),
      );
    }

    final block = _data!['block'] as Map<String, Object?>;
    final blockTotals = _data!['block_totals'] as Map<String, Object?>;
    final workouts = _data!['workouts'] as List<Map<String, Object?>>;
    final improvementMetrics =
    _data!['improvement_metrics'] as Map<String, Object?>;
    final badges = _data!['badges'] as List<Map<String, Object?>>;
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

    final bestWorkoutTitle =
        (improvementMetrics['best_workout_title'] as String?) ?? '-';
    final bestWorkoutScore =
    ((improvementMetrics['best_workout_score'] as num?) ?? 0).toDouble();

    final highestWorkloadTitle =
        (improvementMetrics['highest_workload_title'] as String?) ?? '-';
    final highestWorkoutWorkload =
    ((improvementMetrics['highest_workload'] as num?) ?? 0).toDouble();

    final mostImprovedTitle =
        (improvementMetrics['most_improved_title'] as String?) ?? '-';
    final mostImprovedDelta =
    ((improvementMetrics['most_improved_delta'] as num?) ?? 0).toDouble();

    final averageWorkoutScore = totalWorkoutCount == 0
        ? 0.0
        : workouts.fold<double>(
      0.0,
          (sum, workout) =>
      sum + (((workout['workout_score'] as num?) ?? 0).toDouble()),
    ) /
        totalWorkoutCount;

    return Scaffold(
      backgroundColor: _screenBackground,
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
              bestWorkoutTitle: bestWorkoutTitle,
              bestWorkoutScore: bestWorkoutScore,
              highestWorkloadTitle: highestWorkloadTitle,
              highestWorkoutWorkload: highestWorkoutWorkload,
              averageWorkoutScore: averageWorkoutScore,
              mostImprovedTitle: mostImprovedTitle,
              mostImprovedDelta: mostImprovedDelta,
            ),
            const SizedBox(height: 12),
            _MilestonesCard(badges: badges),
            const SizedBox(height: 16),
            Text(
              'Workout Details',
              style: const TextStyle(
                color: _primaryText,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(color: Colors.white24, height: 1),
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
    return Container(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          children: [
            Text(
              blockTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Summary',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            if (category.isNotEmpty)
              Text(
                category,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            Text(
              'Run $runNumber',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white24, height: 1),
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
    return Container(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: const Text(
                'Overview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Block Score',
                    value: blockScore.toStringAsFixed(2),
                    valueColor: const Color(0xFF1565C0),
                  ),
                ),
                Expanded(
                  child: _StatTile(
                    label: 'Total Workload',
                    value: totalWorkload.toStringAsFixed(0),
                    valueColor: const Color(0xFF3A3A3A),
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
                    valueColor: const Color(0xFF3A3A3A),
                  ),
                ),
                Expanded(
                  child: _StatTile(
                    label: 'Days Taken',
                    value: trainingDays.toString(),
                    valueColor: const Color(0xFF3A3A3A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
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

    return Container(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: const Text(
                'Plan Adherence',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
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
              child: Text(
                adherenceLabel,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Completed $completedWorkoutCount of $totalWorkoutCount scheduled workouts in $trainingDays training days.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
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
  final String mostImprovedTitle;
  final double mostImprovedDelta;

  const _ImprovementCard({
    required this.bestWorkoutTitle,
    required this.bestWorkoutScore,
    required this.highestWorkloadTitle,
    required this.highestWorkoutWorkload,
    required this.averageWorkoutScore,
    required this.mostImprovedTitle,
    required this.mostImprovedDelta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: const Text(
                'Improvements',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
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
            const SizedBox(height: 8),
            _InfoRow(
              label: 'Most Improved',
              value: mostImprovedDelta > 0
                  ? '$mostImprovedTitle (+${mostImprovedDelta.toStringAsFixed(2)})'
                  : '-',
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
          ],
        ),
      ),
    );
  }
}

class _MilestonesCard extends StatelessWidget {
  final List<Map<String, Object?>> badges;

  const _MilestonesCard({
    required this.badges,
  });

  String _formatBadgeKey(String key) {
    final definition = BadgeDefinitions.stock[key];
    if (definition != null) {
      return definition.title;
    }

    return key
        .split('_')
        .where((part) => part.isNotEmpty)
        .map(
          (part) => '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  Map<String, Object?>? _parseMetadata(Object? rawMetadata) {
    if (rawMetadata is! String || rawMetadata.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawMetadata);
      if (decoded is! Map) {
        return null;
      }

      return decoded.map((key, value) => MapEntry(key.toString(), value));
    } on FormatException {
      return null;
    }
  }

  String? _buildBadgeDetail({
    required String badgeKey,
    required Map<String, Object?> badge,
  }) {
    final metadata = _parseMetadata(badge['metadata_json']);
    if (metadata == null) {
      return null;
    }

    if (badgeKey == BadgeKeys.lunchLady) {
      final liftKey = metadata['lift_key'] as String?;
      if (liftKey == null || liftKey.isEmpty) {
        return null;
      }
      return 'Lift: ${_formatBadgeKey(liftKey)}';
    }

    if (badgeKey == BadgeKeys.meatWagon) {
      final threshold = metadata['threshold_lbs'] as num?;
      if (threshold == null) {
        return null;
      }
      return 'Threshold: ${threshold.toStringAsFixed(0)} lbs';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: const Text(
                'Milestones & Badges',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (badges.isEmpty)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No badges earned during this block yet.',
                  style: TextStyle(color: Colors.white70),
                ),
              )
            else
              ...badges.map((badge) {
                final badgeKey = (badge['badge_key'] as String?) ?? '';
                final awardedAt = (badge['awarded_at'] as String?) ?? '';
                final detail = _buildBadgeDetail(
                  badgeKey: badgeKey,
                  badge: badge,
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _formatBadgeKey(badgeKey),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            awardedAt.isEmpty
                                ? ''
                                : awardedAt.split('T').first,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      if (detail != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          detail,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            const Divider(color: Colors.white12, height: 1),
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

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white12),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (dayLabel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      dayLabel,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Status: $status',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Score: ${score.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFF1565C0),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Workload: ${workload.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white70),
                ),
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
  final Color valueColor;

  const _StatTile({
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: valueColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
      ),
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
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
