import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../core/logger/app_logger.dart';

/// Manages background execution for file transfers on mobile platforms.
class BackgroundService {
  final AppLogger _logger = AppLogger();
  bool _isRunning = false;

  /// Start the background service (Android foreground service).
  Future<void> start() async {
    if (_isRunning) return;
    final service = FlutterBackgroundService();

    // Configure the service
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'transfer_channel',
        initialNotificationTitle: 'FileShare',
        initialNotificationContent: 'Ready to transfer files',
        foregroundServiceNotificationId: 1000,
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );

    await service.startService();
    _isRunning = true;
    _logger.info('Background service started');
  }

  /// Update the foreground notification with current transfer info.
  Future<void> updateNotification({
    required String title,
    required String content,
  }) async {
    final service = FlutterBackgroundService();
    service.invoke('updateNotification', {
      'title': title,
      'content': content,
    });
  }

  /// Stop the background service.
  Future<void> stop() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
    _isRunning = false;
    _logger.info('Background service stopped');
  }

  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    // iOS background fetch — limited to ~30 seconds
    // Use this for saving transfer state before app suspension
    return true;
  }

  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) async {
    if (service is AndroidServiceInstance) {
      service.on('updateNotification').listen((event) {
        final title = event?['title'] as String? ?? 'FileShare';
        final content = event?['content'] as String? ?? '';
        service.setForegroundNotificationInfo(
          title: title,
          content: content,
        );
      });

      service.on('stopService').listen((event) {
        service.stopSelf();
      });

      // Keep the service alive
      Timer.periodic(const Duration(seconds: 10), (timer) async {
        if (!(await service.isForegroundService())) {
          timer.cancel();
        }
      });
    }
  }
}
