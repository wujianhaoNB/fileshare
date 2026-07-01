import 'dart:async';
import 'package:multicast_dns/multicast_dns.dart';
import '../../core/constants/app_constants.dart';
import '../../core/logger/app_logger.dart';
import '../../data/models/device.dart';

/// Manages mDNS service discovery for device finding.
///
/// Uses multicast_dns 0.3.x API: start/stop the client, and periodically
/// query for PTR records via [MDnsClient.lookup]. Service advertising
/// (registerService) is not available in this API version — use the
/// subnet scanner as the primary discovery mechanism.
class MdnsDiscovery {
  final MDnsClient _client = MDnsClient();
  final AppLogger _logger = AppLogger();
  bool _isRunning = false;

  Timer? _queryTimer;

  final _deviceController = StreamController<Device>.broadcast();
  Stream<Device> get discoveredDevices => _deviceController.stream;

  /// Start the mDNS client and begin periodic service discovery.
  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;

    try {
      await _client.start();
      _logger.info('mDNS client started');

      // Initial query
      _queryServices();

      // Periodically re-query for new services
      _queryTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _queryServices(),
      );
    } catch (e) {
      _logger.error('Failed to start mDNS client', e);
      _isRunning = false;
    }
  }

  /// Refresh discovery by re-querying for services immediately.
  Future<void> refresh() async {
    _queryServices();
  }

  void _queryServices() {
    if (!_isRunning) return;

    final stream = _client.lookup<PtrResourceRecord>(
      ResourceRecordQuery.serverPointer(AppConstants.serviceType),
    );

    stream.listen(
      (PtrResourceRecord ptr) {
        if (ptr.domainName == AppConstants.serviceType) {
          _resolveService(ptr);
        }
      },
      onError: (Object error) {
        _logger.debug('mDNS query error: $error');
      },
    );
  }

  Future<void> _resolveService(PtrResourceRecord ptr) async {
    try {
      // Resolve SRV record for host and port
      final srvList = await _client
          .lookup<SrvResourceRecord>(
            ResourceRecordQuery.service(ptr.domainName),
          )
          .toList();

      if (srvList.isEmpty) return;
      final srv = srvList.first;

      // Resolve TXT record for properties
      final txtList = await _client
          .lookup<TxtResourceRecord>(
            ResourceRecordQuery.text(ptr.domainName),
          )
          .toList();

      final properties = <String, String>{};
      if (txtList.isNotEmpty) {
        final txt = txtList.first;
        txt.text.split(';').forEach((pair) {
          final eq = pair.indexOf('=');
          if (eq > 0) {
            properties[pair.substring(0, eq)] = pair.substring(eq + 1);
          }
        });
      }

      // Find the IP address for the host
      final addrList = await _client
          .lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(srv.target),
          )
          .toList();

      if (addrList.isEmpty) return;

      final ip = addrList.first.address.address;

      final device = Device.fromMdns(
        ip: ip,
        port: srv.port,
        name: properties['name'] ?? srv.target,
        txtRecords: properties,
      );

      _deviceController.add(device);
      _logger.info(
          'Discovered device: ${device.displayName} at $ip:${srv.port}');
    } catch (e) {
      _logger.debug('Failed to resolve mDNS service: $e');
    }
  }

  /// Shut down the mDNS client.
  Future<void> stop() async {
    _isRunning = false;
    _queryTimer?.cancel();
    _queryTimer = null;

    try {
      _client.stop();
      _logger.info('mDNS client stopped');
    } catch (e) {
      _logger.error('Error stopping mDNS client', e);
    }
    await _deviceController.close();
  }
}
