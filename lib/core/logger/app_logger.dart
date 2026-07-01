import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart' as log;

/// Centralized application logger.
class AppLogger {
  factory AppLogger() => _instance;
  AppLogger._() {
    _logger = log.Logger(
      level: log.Level.info,
      printer: log.PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        dateTimeFormat: log.DateTimeFormat.dateAndTime,
      ),
      filter: DebugFilter(),
    );
  }

  static final AppLogger _instance = AppLogger._();

  late log.Logger _logger;

  void init({bool debugMode = false}) {
    _logger = log.Logger(
      level: debugMode ? log.Level.trace : log.Level.info,
      printer: log.PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        dateTimeFormat: log.DateTimeFormat.dateAndTime,
      ),
      filter: DebugFilter(),
    );
  }

  void trace(String message) => _logger.t(message);
  void debug(String message) => _logger.d(message);
  void info(String message) => _logger.i(message);
  void warn(String message) => _logger.w(message);
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }
  void fatal(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }
}

/// Prevents debug-level logs in release mode.
class DebugFilter extends log.LogFilter {
  @override
  bool shouldLog(log.LogEvent event) {
    if (kReleaseMode && event.level == log.Level.debug) return false;
    if (kReleaseMode && event.level == log.Level.trace) return false;
    return true;
  }
}
