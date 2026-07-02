import 'dart:async';
import 'package:flutter/services.dart';
import '../core/logger/app_logger.dart';

/// Notification data received from Android NotificationListenerService.
class PhoneNotification {
  final int id;
  final String appName;
  final String title;
  final String text;
  final DateTime timestamp;
  final String? packageName;
  final bool isOngoing;

  const PhoneNotification({
    required this.id, required this.appName, required this.title,
    required this.text, required this.timestamp, this.packageName, this.isOngoing = false,
  });

  factory PhoneNotification.fromMap(Map<String, dynamic> map) => PhoneNotification(
    id: map['id'] as int? ?? 0,
    appName: map['appName'] as String? ?? 'Unknown',
    title: map['title'] as String? ?? '',
    text: map['text'] as String? ?? '',
    timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int? ?? 0),
    packageName: map['packageName'] as String?,
    isOngoing: map['isOngoing'] == true,
  );

  String get summary => title.isNotEmpty ? '$appName: $title' : '$appName: $text';
}

/// SMS message data.
class PhoneSms {
  final int id;
  final String address;
  final String body;
  final DateTime timestamp;
  final bool isRead;
  final int type; // 1=inbox, 2=sent

  const PhoneSms({
    required this.id, required this.address, required this.body,
    required this.timestamp, this.isRead = false, this.type = 1,
  });

  factory PhoneSms.fromMap(Map<String, dynamic> map) => PhoneSms(
    id: map['id'] as int? ?? 0,
    address: map['address'] as String? ?? '',
    body: map['body'] as String? ?? '',
    timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int? ?? 0),
    isRead: map['isRead'] == true,
    type: map['type'] as int? ?? 1,
  );
}

/// Call state info.
class PhoneCall {
  final String phoneNumber;
  final String state; // 'ringing', 'offhook', 'idle'
  final DateTime timestamp;

  const PhoneCall({required this.phoneNumber, required this.state, required this.timestamp});
}

/// Cross-platform phone integration service.
/// Uses MethodChannel for Android native calls. iOS/Win are no-ops.
class PhoneIntegrationService {
  final AppLogger _logger = AppLogger();
  static const _channel = MethodChannel('com.fileshare.app/phone');
  static const _notificationChannel = MethodChannel('com.fileshare.app/notifications');

  final _notificationController = StreamController<PhoneNotification>.broadcast();
  final _smsController = StreamController<PhoneSms>.broadcast();
  final _callController = StreamController<PhoneCall>.broadcast();

  Stream<PhoneNotification> get notifications => _notificationController.stream;
  Stream<PhoneSms> get smsStream => _smsController.stream;
  Stream<PhoneCall> get callStream => _callController.stream;

  bool _isListening = false;

  /// Start listening to phone events. No-op on non-Android platforms.
  Future<void> startListening() async {
    if (_isListening) return;
    _isListening = true;

    try {
      // Set up notification listener
      _notificationChannel.setMethodCallHandler((call) {
        if (call.method == 'onNotification') {
          final notif = PhoneNotification.fromMap(Map<String, dynamic>.from(call.arguments as Map));
          _notificationController.add(notif);
        }
        return Future.value(null);
      });

      // Set up SMS listener
      _channel.setMethodCallHandler((methodCall) {
        switch (methodCall.method) {
          case 'onSmsReceived':
            final sms = PhoneSms.fromMap(Map<String, dynamic>.from(methodCall.arguments as Map));
            _smsController.add(sms);
          case 'onCallState':
            final phoneCall = PhoneCall(
              phoneNumber: methodCall.arguments['number'] as String? ?? '',
              state: methodCall.arguments['state'] as String? ?? 'idle',
              timestamp: DateTime.now(),
            );
            _callController.add(phoneCall);
        }
        return Future.value(null);
      });

      // Request Android to start listening
      await _channel.invokeMethod('startListening');
      await _notificationChannel.invokeMethod('startNotificationListener');
      _logger.info('Phone integration started');
    } catch (e) {
      _logger.debug('Phone integration not available on this platform: $e');
    }
  }

  /// Request notification access permission (Android only).
  Future<bool> requestNotificationPermission() async {
    try {
      return await _notificationChannel.invokeMethod('requestNotificationPermission') == true;
    } catch (_) {
      return false;
    }
  }

  /// Send an SMS (Android only, may require user approval).
  Future<bool> sendSms(String phoneNumber, String message) async {
    try {
      return await _channel.invokeMethod('sendSms', {'number': phoneNumber, 'message': message}) == true;
    } catch (e) {
      _logger.error('Failed to send SMS', e);
      return false;
    }
  }

  /// Get recent SMS messages.
  Future<List<PhoneSms>> getRecentSms({int count = 20}) async {
    try {
      final result = await _channel.invokeMethod('getRecentSms', {'count': count});
      if (result is List) {
        return result.map((m) => PhoneSms.fromMap(Map<String, dynamic>.from(m as Map))).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Get recent notifications.
  Future<List<PhoneNotification>> getRecentNotifications({int count = 20}) async {
    try {
      final result = await _notificationChannel.invokeMethod('getRecentNotifications', {'count': count});
      if (result is List) {
        return result.map((m) => PhoneNotification.fromMap(Map<String, dynamic>.from(m as Map))).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> stop() async {
    await _notificationController.close();
    await _smsController.close();
    await _callController.close();
  }
}
