import 'dart:async';
import '../../core/logger/app_logger.dart';
import '../../data/models/device.dart';
import 'mdns_discovery.dart';
import 'subnet_scanner.dart';

/// Combines mDNS and subnet scanning for robust device discovery.
class CompositeDiscovery {
  final MdnsDiscovery _mdns = MdnsDiscovery();
  final SubnetScanner _subnetScanner = SubnetScanner();
  final AppLogger _logger = AppLogger();

  final _deviceController = StreamController<Device>.broadcast();
  final _knownDevices = <String, Device>{};

  bool _isRunning = false;

  /// Stream of all discovered devices (deduplicated by ID).
  Stream<Device> get devices => _deviceController.stream;

  /// All currently known devices.
  List<Device> get knownDevices => _knownDevices.values.toList();

  /// Start discovery (mDNS + subnet scan).
  Future<void> start({
    required String deviceName,
    required int port,
    bool hasBluetooth = false,
    List<String>? knownIps,
  }) async {
    if (_isRunning) return;
    _isRunning = true;

    _logger.info('Starting composite discovery');

    // Listen to both discovery sources
    _mdns.discoveredDevices.listen(_onDeviceFound);
    _subnetScanner.discoveredDevices.listen(_onDeviceFound);

    // Start mDNS (advertising not supported in current multicast_dns version;
    // subnet scanner handles active discovery)
    await _mdns.start();

    // Run subnet scan in parallel
    _subnetScanner.scan(knownIps: knownIps);
  }

  /// Refresh discovery.
  Future<void> refresh({List<String>? knownIps}) async {
    _knownDevices.clear();
    await _mdns.refresh();
    unawaited(_subnetScanner.scan(knownIps: knownIps));
  }

  void _onDeviceFound(Device device) {
    final key = device.id;
    if (_knownDevices.containsKey(key)) {
      // Update last seen
      _knownDevices[key] = device.copyWith(lastSeenAt: DateTime.now());
    } else {
      _knownDevices[key] = device;
    }
    _deviceController.add(device);
    _logger.debug('Device updated: ${device.displayName} (${device.ip})');
  }

  /// Stop all discovery.
  Future<void> stop() async {
    _isRunning = false;
    await _mdns.stop();
    await _subnetScanner.stop();
    await _deviceController.close();
    _logger.info('Composite discovery stopped');
  }
}
