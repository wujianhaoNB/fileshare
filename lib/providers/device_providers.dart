import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/device.dart';
import 'service_providers.dart';

/// Stream of currently discovered + paired devices.
final discoveredDevicesProvider = StreamProvider<List<Device>>((ref) {
  final discoveryService = ref.watch(discoveryServiceProvider);
  return discoveryService.allDevices;
});

/// Whether discovery is actively searching.
final isSearchingProvider = StateProvider<bool>((ref) => false);

/// Selected device (for sending files).
final selectedDeviceProvider = StateProvider<Device?>((ref) => null);
