import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
  Future<void> scan({List<String>? knownIps, String? ownIp}) async {
    final localIp = await NetworkUtils.getLocalIp();
    if (localIp == null) {
      _logger.warn('No local IP found, skipping subnet scan');
      return;
    }

    _logger.info('Starting subnet scan from $localIp');

    // First, try known IPs (faster)
    if (knownIps != null && knownIps.isNotEmpty) {
      await _probeAddresses(knownIps, ownIp: ownIp, priority: true);
    }

    // Then scan the full /24 subnet
    final subnet = NetworkUtils.getSubnetRange(localIp);
    await _probeAddresses(subnet, ownIp: ownIp, priority: false);
  }

  Future<void> _probeAddresses(List<String> addresses, {String? ownIp, required bool priority}) async {
    // Limit concurrency to avoid flooding
    const concurrency = 20;
    final queue = [...addresses];

    Future<void> probeAll() async {
      while (queue.isNotEmpty) {
        final batch = <String>[];
        for (var i = 0; i < concurrency && queue.isNotEmpty; i++) {
          batch.add(queue.removeAt(0));
        }

        await Future.wait(batch.map((ip) => _probeSingle(ip, ownIp: ownIp)));
      }
    }

    await probeAll();
  }

  Future<void> _probeSingle(String ip, {String? ownIp}) async {
    // Skip own IP
    if (ip == ownIp) return;
    // Skip loopback
    if (ip == '127.0.0.1' || ip.startsWith('127.')) return;

    try {
      // Try a real HTTP GET /discover to validate it's a FileShare device
      final client = HttpClient();
      client.connectionTimeout = AppConstants.subnetScanTimeout;
      try {
        final request = await client
            .getUrl(Uri.parse('http://$ip:${AppConstants.defaultControlPort}/discover'));
        final response = await request.close().timeout(
          AppConstants.subnetScanTimeout,
        );

        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final json = jsonDecode(body) as Map<String, dynamic>;

          final device = Device(
            id: 'scan_$ip',
            displayName: json['device_name'] as String? ?? 'Unknown',
            ip: ip,
            port: json['data_port'] as int? ?? AppConstants.defaultDataPort,
            trustLevel: 0,
            hasBluetooth: json['has_bluetooth'] == true,
            appVersion: json['app_version'] as String?,
            isOnline: true,
            lastSeenAt: DateTime.now(),
          );

          _deviceController.add(device);
          _logger.info('Subnet scan found device: ${device.displayName} at $ip');
        }
      } finally {
        client.close();
      }
    } catch (_) {
      // Not a FileShare device or timeout — skip
    }
  }

  Future<void> stop() async {
    await _deviceController.close();
  }
}
