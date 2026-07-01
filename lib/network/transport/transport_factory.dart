import '../../core/logger/app_logger.dart';
import 'transport.dart';
import 'tcp_transport.dart';
import 'bluetooth_transport.dart';

/// Creates the appropriate transport based on availability and preferences.
class TransportFactory {
  final AppLogger _logger = AppLogger();

  /// Preferred transport order: TCP (fast) → BLE (fallback)
  Transport createTcp() {
    _logger.info('Creating TCP transport');
    return TcpTransport();
  }

  Transport createBluetooth() {
    _logger.info('Creating Bluetooth transport');
    return BluetoothTransport();
  }

  /// Attempt TCP first, fall back to Bluetooth.
  /// Returns the transport that successfully connected.
  Future<({Transport transport, TransportType type})> connectWithFallback({
    required String address,
    required int tcpPort,
    String? bleAddress,
    bool useBluetoothFallback = true,
  }) async {
    // Try TCP first
    try {
      final tcp = createTcp();
      await tcp.connect(address, tcpPort);
      _logger.info('Connected via TCP');
      return (transport: tcp, type: TransportType.tcp);
    } catch (e) {
      _logger.warn('TCP connection failed: $e');

      if (!useBluetoothFallback || bleAddress == null) {
        rethrow;
      }

      // Fall back to Bluetooth
      try {
        final ble = createBluetooth();
        await ble.connect(bleAddress, 0); // BLE doesn't use ports
        _logger.info('Connected via Bluetooth (fallback)');
        return (transport: ble, type: TransportType.bluetooth);
      } catch (bleError) {
        _logger.error('Bluetooth fallback also failed', bleError);
        rethrow;
      }
    }
  }
}

enum TransportType { tcp, bluetooth, relay }
