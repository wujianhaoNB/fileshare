import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Cross-platform permission handling utilities.
class PermissionUtils {
  PermissionUtils._();

  /// Request storage permissions (platform-appropriate).
  static Future<bool> requestStoragePermission() async {
    if (kIsWeb) return true;

    if (Platform.isAndroid) {
      // Android 13+ uses granular media permissions
      final status = await Permission.storage.request();
      if (status.isGranted) return true;

      // Fall back to manageExternalStorage for Android 11-12
      final manageStatus = await Permission.manageExternalStorage.request();
      return manageStatus.isGranted;
    }

    if (Platform.isIOS) {
      // iOS uses document picker - no persistent storage permission needed
      return true;
    }

    // Windows/macOS/Linux - no special permission needed
    return true;
  }

  /// Request camera permission (for QR scanning).
  static Future<bool> requestCameraPermission() async {
    if (kIsWeb) return true;
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Request location permission (needed for Wi-Fi scanning on Android).
  static Future<bool> requestLocationPermission() async {
    if (kIsWeb) return true;

    if (Platform.isAndroid) {
      final status = await Permission.location.request();
      return status.isGranted;
    }

    // iOS doesn't require location for local network
    return true;
  }

  /// Request Bluetooth permissions.
  static Future<bool> requestBluetoothPermission() async {
    if (kIsWeb) return true;

    if (Platform.isAndroid) {
      final status = await Permission.bluetooth.request();
      if (!status.isGranted) return false;

      final connectStatus = await Permission.bluetoothConnect.request();
      final scanStatus = await Permission.bluetoothScan.request();
      return connectStatus.isGranted && scanStatus.isGranted;
    }

    if (Platform.isIOS) {
      // iOS uses its own Bluetooth entitlement system
      return true;
    }

    return true;
  }

  /// Request notification permission (Android 13+).
  static Future<bool> requestNotificationPermission() async {
    if (kIsWeb) return true;
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    return true;
  }

  /// Request all permissions needed for the app to function.
  static Future<Map<String, bool>> requestAll() async {
    final results = <String, bool>{};
    results['storage'] = await requestStoragePermission();
    results['camera'] = await requestCameraPermission();
    results['location'] = await requestLocationPermission();
    results['bluetooth'] = await requestBluetoothPermission();
    results['notification'] = await requestNotificationPermission();
    return results;
  }
}
