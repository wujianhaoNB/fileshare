import 'dart:async';
import '../../core/constants/app_constants.dart';
import '../../core/logger/app_logger.dart';
import '../../core/utils/network_utils.dart';
import '../../data/models/device.dart';

/// Fallback discovery: scan the local subnet for FileShare devices.
class SubnetScanner {
  final AppLogger _logger = AppLogger();
  final _deviceController = StreamController<Device>.broadcast();

  Stream<Device> get discoveredDevices => _deviceController.stream;

  /// Scan the local subnet for devices listening on the FileShare control port.
  Future<void> scan({List<String>? knownIps}) async {
    final localIp = await NetworkUtils.getLocalIp();
    if (localIp == null) {
      _logger.warn('No local IP found, skipping subnet scan');
      return;
    }

    _logger.info('Starting subnet scan from $localIp');

    // First, try known IPs (faster)
    if (knownIps != null && knownIps.isNotEmpty) {
      await _probeAddresses(knownIps, priority: true);
    }

    // Then scan the full /24 subnet
    final subnet = NetworkUtils.getSubnetRange(localIp);
    await _probeAddresses(subnet, priority: false);
  }

  Future<void> _probeAddresses(List<String> addresses, {required bool priority}) async {
    // Limit concurrency to avoid flooding
    const concurrency = 20;
    final queue = [...addresses];

    Future<void> probeAll() async {
      while (queue.isNotEmpty) {
        final batch = <String>[];
        for (var i = 0; i < concurrency && queue.isNotEmpty; i++) {
          batch.add(queue.removeAt(0));
        }

        await Future.wait(batch.map((ip) => _probeSingle(ip)));
      }
    }

    await probeAll();
  }

  Future<void> _probeSingle(String ip) async {
    final reachable = await NetworkUtils.probeHost(
      ip,
      AppConstants.defaultControlPort,
      timeout: AppConstants.subnetScanTimeout,
    );

    if (reachable) {
      // Found a device - we don't know its name yet, but we know it's reachable
      final device = Device(
        id: 'scan_$ip',
        displayName: 'Device at $ip',
        ip: ip,
        port: AppConstants.defaultControlPort,
        trustLevel: 0,
        isOnline: true,
        lastSeenAt: DateTime.now(),
      );

      _deviceController.add(device);
      _logger.info('Subnet scan found device at $ip');
    }
  }

  Future<void> stop() async {
    await _deviceController.close();
  }
}
