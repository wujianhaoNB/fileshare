import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/logger/app_logger.dart';
import 'services/file_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error handler — prevent gray screen on any crash
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    AppLogger().error('Flutter error: ${details.exception}', details.exception);
  };

  // Catch any startup error
  try {
    AppLogger().init(debugMode: false);

    final fileManager = FileManager();
    await fileManager.init();
    await fileManager.cleanupTempFiles();
  } catch (e) {
    // If startup fails, still launch the app — it'll show error state
    AppLogger().error('Startup error: $e', e);
  }

  runApp(
    const ProviderScope(
      child: FileShareApp(),
    ),
  );
}
