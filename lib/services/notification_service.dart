import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/logger/app_logger.dart';

/// Manages foreground notifications for active transfers.
class NotificationService {
  final AppLogger _logger = AppLogger();
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize the notification plugin.
  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _initialized = true;
    _logger.info('Notification service initialized');
  }

  void _onNotificationTap(NotificationResponse response) {
    _logger.info('Notification tapped: ${response.payload}');
    // The router will handle navigation based on payload
  }

  /// Show or update a transfer progress notification.
  Future<void> showTransferProgress({
    required int notificationId,
    required String fileName,
    required int progress,
    required int maxProgress,
    required String speed,
    bool isIncoming = false,
  }) async {
    final direction = isIncoming ? 'Receiving' : 'Sending';

    if (Platform.isAndroid) {
      await _plugin.show(
        notificationId,
        '$direction $fileName',
        '$progress% · $speed',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'transfer_channel',
            'File Transfers',
            channelDescription: 'Shows transfer progress',
            importance: Importance.low,
            priority: Priority.low,
            onlyAlertOnce: true,
            showProgress: true,
            maxProgress: maxProgress,
            progress: progress,
            ongoing: true,
            autoCancel: false,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: false,
            presentBadge: true,
            presentSound: false,
          ),
        ),
        payload: 'transfer_$notificationId',
      );
    } else {
      // iOS doesn't support progress notifications natively — use badge
      await _plugin.show(
        notificationId,
        '$direction $fileName',
        '$progress% · $speed',
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: false,
            presentBadge: true,
            presentSound: false,
          ),
        ),
        payload: 'transfer_$notificationId',
      );
    }
  }

  /// Show a transfer complete notification.
  Future<void> showTransferComplete({
    required int notificationId,
    required String fileName,
    required bool isIncoming,
  }) async {
    final action = isIncoming ? 'Received' : 'Sent';
    await _plugin.show(
      notificationId,
      'Transfer Complete',
      '$action: $fileName',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'transfer_complete_channel',
          'Transfer Complete',
          channelDescription: 'Shows when transfers finish',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'transfer_$notificationId',
    );
  }

  /// Show a transfer error notification.
  Future<void> showTransferError({
    required int notificationId,
    required String fileName,
    required String error,
  }) async {
    await _plugin.show(
      notificationId,
      'Transfer Failed',
      '$fileName: $error',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'transfer_error_channel',
          'Transfer Errors',
          channelDescription: 'Shows transfer failures',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Cancel a specific notification.
  Future<void> cancel(int notificationId) async {
    await _plugin.cancel(notificationId);
  }

  /// Cancel all notifications.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
