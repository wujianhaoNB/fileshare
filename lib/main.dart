import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/logger/app_logger.dart';
import 'services/file_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // MUST init logger first — other services depend on it
  AppLogger().init(debugMode: true);

  // Initialize file manager before the app starts
  final fileManager = FileManager();
  await fileManager.init();

  // Clean up old temp files
  await fileManager.cleanupTempFiles();

  runApp(
    const ProviderScope(
      child: FileShareApp(),
    ),
  );
}
