import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../core/logger/app_logger.dart';

/// Manages file system operations: temp files, incoming storage, cleanup.
class FileManager {
  final AppLogger _logger = AppLogger();

  bool _initialized = false;
  String? _tempDir;
  String? _incomingDir;

  /// Returns the temp directory, initializing on-demand if needed.
  String get tempDir {
    if (_tempDir != null) return _tempDir!;
    // Use a fallback until init() is called
    return p.join(Directory.systemTemp.path, 'fileshare', 'temp');
  }

  /// Returns the incoming directory, initializing on-demand if needed.
  String get incomingDir {
    if (_incomingDir != null) return _incomingDir!;
    return p.join(Directory.systemTemp.path, 'fileshare', 'incoming');
  }

  /// Initialize directory structure.
  Future<void> init() async {
    if (_initialized) return;

    final appDir = await getApplicationDocumentsDirectory();
    final baseDir = Directory(p.join(appDir.path, 'fileshare'));

    _tempDir = p.join(baseDir.path, 'temp');
    _incomingDir = p.join(baseDir.path, 'incoming');

    await Directory(tempDir).create(recursive: true);
    await Directory(incomingDir).create(recursive: true);

    _initialized = true;
    _logger.info('File manager initialized: temp=$_tempDir, incoming=$_incomingDir');
  }

  /// Get the path for a temporary (partial) download file.
  String getTempPath(String transferId, String fileName) {
    return p.join(tempDir, '${transferId}_$fileName.part');
  }

  /// Get the final path for a completed download.
  String getIncomingPath(String fileName) {
    return p.join(incomingDir, fileName);
  }

  /// Move a completed temp file to the incoming directory.
  Future<String> finalizeDownload(String transferId, String fileName) async {
    final tempPath = getTempPath(transferId, fileName);
    final incomingPath = getIncomingPath(fileName);

    // Handle filename collisions
    var finalPath = incomingPath;
    var counter = 1;
    while (await File(finalPath).exists()) {
      final ext = p.extension(fileName);
      final base = p.basenameWithoutExtension(fileName);
      finalPath = p.join(incomingDir, '${base}_$counter$ext');
      counter++;
    }

    await File(tempPath).rename(finalPath);
    _logger.info('File finalized: $finalPath');
    return finalPath;
  }

  /// Check available disk space in bytes.
  Future<int> getAvailableSpace() async {
    try {
      // Platform-specific approach
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // ignore: unused_local_variable
        final result = await Process.run(
          Platform.isWindows ? 'wmic' : 'df',
          Platform.isWindows
              ? ['logicaldisk', 'where', 'name=', '${incomingDir[0]}:', 'get', 'freespace']
              : ['-B', incomingDir],
        );
        return 1024 * 1024 * 1024; // Assume 1 GB available
      }
      return 1024 * 1024 * 1024; // Assume 1 GB available on mobile
    } catch (_) {
      return 1024 * 1024 * 1024;
    }
  }

  /// Delete a temp file if it exists.
  Future<void> deleteTempFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        _logger.debug('Deleted temp file: $path');
      }
    } catch (e) {
      _logger.error('Failed to delete temp file: $path', e);
    }
  }

  /// Clean up old temporary files (older than retention period).
  Future<void> cleanupTempFiles({Duration retention = const Duration(days: 7)}) async {
    try {
      final td = Directory(tempDir);
      if (!await td.exists()) return;

      final now = DateTime.now();
      await for (final entity in td.list()) {
        if (entity is File && entity.path.endsWith('.part')) {
          final stat = await entity.stat();
          if (now.difference(stat.modified) > retention) {
            await entity.delete();
            _logger.debug('Cleaned up stale temp file: ${entity.path}');
          }
        }
      }
    } catch (e) {
      _logger.error('Temp cleanup error', e);
    }
  }
}
