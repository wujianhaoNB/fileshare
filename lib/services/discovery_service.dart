import 'dart:async';
import '../core/logger/app_logger.dart';
import '../data/models/device.dart';
import '../data/repositories/device_repository.dart';
import '../network/discovery/composite_discovery.dart';

/// Orchestrates device discovery by combining composite discovery with paired device data.
class DiscoveryService {
  final AppLogger _logger = AppLogger();
  final CompositeDiscovery _compositeDiscovery = CompositeDiscovery();
  final DeviceRepository _deviceRepository;

  final _allDevicesController = StreamController<List<Device>>.broadcast();
  final _discoveredDevices = <String, Device>{};
  Timer? _refreshTimer;

  DiscoveryService({required DeviceRepository deviceRepository})
      : _deviceRepository = deviceRepository;

  /// Stream of all known devices (paired + discovered).
  Stream<List<Device>> get allDevices => _allDevicesController.stream;

  /// Start the discovery service.
  Future<void> start({
    required String deviceName,
    int port = 8080,
    bool hasBluetooth = false,
  }) async {
    _logger.info('Starting discovery service');

    // Load paired devices for known IP cache
    final paired = await _deviceRepository.getPairedDevices();
    final knownIps = paired.where((d) => d.ip.isNotEmpty).map((d) => d.ip).toList();

    // Listen to composite discovery
    _compositeDiscovery.devices.listen((device) {
      // Merge with paired info if available
      final existingPaired = paired.where(
        (p) => p.publicKey != null && p.publicKey == device.publicKey,
      );
      if (existingPaired.isNotEmpty) {
        device = device.copyWith(
          trustLevel: existingPaired.first.trustLevel,
          displayName: existingPaired.first.displayName,
        );
      }
      _discoveredDevices[device.id] = device;
      _emitDevices();
    });

    // Start composite discovery
    await _compositeDiscovery.start(
      deviceName: deviceName,
      port: port,
      hasBluetooth: hasBluetooth,
      knownIps: knownIps,
    );

    // Also add paired devices (even if offline)
    for (final p in paired) {
      _discoveredDevices[p.id] = p;
    }
    _emitDevices();

    // Periodic refresh
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _refresh();
    });
  }

  void _emitDevices() {
    final sorted = _discoveredDevices.values.toList()
      ..sort((a, b) {
        // Paired first, then online, then by name
        if (a.isPaired != b.isPaired) return a.isPaired ? -1 : 1;
        if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
        return a.displayName.compareTo(b.displayName);
      });
    _allDevicesController.add(sorted);
  }

  Future<void> _refresh() async {
    final paired = await _deviceRepository.getPairedDevices();
    final knownIps = paired.where((d) => d.ip.isNotEmpty).map((d) => d.ip).toList();
    await _compositeDiscovery.refresh(knownIps: knownIps);
  }

  /// Manual refresh.
  Future<void> refresh() async {
    _discoveredDevices.clear();
    await _refresh();
  }

  /// Stop the discovery service.
  Future<void> stop() async {
    _refreshTimer?.cancel();
    await _compositeDiscovery.stop();
    await _allDevicesController.close();
    _logger.info('Discovery service stopped');
  }
}
