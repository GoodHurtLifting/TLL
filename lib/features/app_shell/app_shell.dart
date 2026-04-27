import 'package:flutter/material.dart';
import 'package:the_lift_league/data/local/services/app_launch_service.dart';
import 'package:the_lift_league/features/blocks/presentation/block_dashboard_screen.dart';
import 'package:the_lift_league/features/blocks/presentation/block_summary_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _isLoading = true;
  int? _blockInstanceId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      final blockInstanceId =
      await AppLaunchService.instance.getOrCreateStarterBlockInstance(
        userId: 'local_test_user',
      );

      if (!mounted) return;

      setState(() {
        _blockInstanceId = blockInstanceId;
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
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: SelectableText(
              _error!,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      );
    }

    return BlockSummaryScreen(
      blockInstanceId: _blockInstanceId!,
    );
  }
}