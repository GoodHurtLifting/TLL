import 'package:flutter/material.dart';

import 'app/tll_app.dart';
import 'data/local/db/db_service.dart';
import 'data/local/seed/seed_runner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await DbService.instance.database;
  await SeedRunner.seedAll();

  runApp(const TllApp());
}