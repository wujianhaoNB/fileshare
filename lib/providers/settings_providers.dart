import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Device name for local identification.
final deviceNameProvider = StateProvider<String>((ref) => 'My Device');

/// Control port for HTTP server.
final controlPortProvider = StateProvider<int>((ref) => 8080);

/// Data port for TCP transfers.
final dataPortProvider = StateProvider<int>((ref) => 9876);

/// Whether the app is currently serving (HTTP + TCP servers running).
final isServerRunningProvider = StateProvider<bool>((ref) => false);

/// Whether Bluetooth is enabled for discovery.
final bluetoothEnabledProvider = StateProvider<bool>((ref) => false);
