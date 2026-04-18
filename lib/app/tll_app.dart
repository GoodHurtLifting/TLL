import 'package:flutter/material.dart';
import '../features/app_shell/app_shell.dart';

class TllApp extends StatelessWidget {
  const TllApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Lift League',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const AppShell(),
    );
  }
}