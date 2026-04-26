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
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          centerTitle: true,
          title: const Text(
            'BLOCK DASHBOARD',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final block = _data!['block'] as Map<String, Object?>;
    final workouts = _data!['workouts'] as List<Map<String, Object?>>;
    final blockTotals = _data!['block_totals'] as Map<String, Object?>;

    final title = (block['title_snapshot'] as String?) ?? 'Block';
    final blockScore = ((blockTotals['block_score'] as num?) ?? 0).toDouble();

    final groupedWorkouts = _groupWorkoutsByWeek(workouts);
    final leaderboardRows = _leaderboardRows(workouts, blockScore);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadBlock,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Center(
              child: Text(
                'The 411',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 20,
                  fontStyle: FontStyle.italic,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.red,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'LEADERBOARD SCORES',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 10),
            ...leaderboardRows,
            const SizedBox(height: 20),
            for (final entry in groupedWorkouts.entries) ...[
              Text(
                'WEEK ${entry.key}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              for (final workout in entry.value)
                _WorkoutRow(
                  workout: workout,
                  onTap: () => _openWorkout(workout['id'] as int),
                ),
              const SizedBox(height: 16),
            ],
            // TODO: Add round-based grouping here if/when schedule type data supports it.
          ],
        ),
      ),
    );
  }

  Map<int, List<Map<String, Object?>>> _groupWorkoutsByWeek(
    List<Map<String, Object?>> workouts,
  ) {
    final sorted = [...workouts]
      ..sort((a, b) {
        final weekA = (a['week_index'] as int?) ?? 1;
        final weekB = (b['week_index'] as int?) ?? 1;
        if (weekA != weekB) return weekA.compareTo(weekB);

        final slotA = (a['workout_slot_index'] as int?) ?? 0;
        final slotB = (b['workout_slot_index'] as int?) ?? 0;
        return slotA.compareTo(slotB);
      });

    final grouped = <int, List<Map<String, Object?>>>{};
    for (final workout in sorted) {
      final week = (workout['week_index'] as int?) ?? 1;
      grouped.putIfAbsent(week, () => <Map<String, Object?>>[]).add(workout);
    }

    return grouped;
  }

  List<Widget> _leaderboardRows(
    List<Map<String, Object?>> workouts,
    double blockScore,
  ) {
    final scored = workouts
        .where((workout) => (workout['workout_score'] as num?) != null)
        .map(
          (workout) => (
            title: ((workout['title_snapshot'] as String?) ?? 'Workout').trim(),
            score: ((workout['workout_score'] as num?) ?? 0).toDouble(),
          ),
        )
        .where((row) => row.score > 0)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final rows = <Widget>[
      _ScoreLine(label: 'Block Total', score: blockScore),
    ];

    final topRows = scored.take(3).toList();
    for (final row in topRows) {
      rows.add(_ScoreLine(label: row.title, score: row.score));
    }

    if (topRows.isEmpty) {
      rows.add(
        const Center(
          child: Text(
            'No workout scores yet',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }

    return rows;
  }
}

class _ScoreLine extends StatelessWidget {
  final String label;
  final double score;

  const _ScoreLine({
    required this.label,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Center(
        child: Text(
          '$label : ${score.toStringAsFixed(1)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _WorkoutRow extends StatelessWidget {
  final Map<String, Object?> workout;
  final VoidCallback onTap;

  const _WorkoutRow({
    required this.workout,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = (workout['title_snapshot'] as String?) ?? 'Workout';
    final workoutScore = ((workout['workout_score'] as num?) ?? 0).toDouble();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          '$title : ${workoutScore.toStringAsFixed(1)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}
