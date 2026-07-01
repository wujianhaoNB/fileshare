import 'dart:convert';
import '../core/logger/app_logger.dart';
import '../core/utils/network_utils.dart';
import '../data/models/device.dart';
import '../data/repositories/device_repository.dart';
import '../network/pairing/pairing_handler.dart';

/// Orchestrates the device pairing flow: QR generation, scanning, handshake.
class PairingService {
  final AppLogger _logger = AppLogger();
  final PairingHandler _handler;
  final DeviceRepository _deviceRepository;

  PairingService({
    required DeviceRepository deviceRepository,
  })  : _deviceRepository = deviceRepository,
        _handler = PairingHandler(deviceRepository: deviceRepository);

  bool get isInitialized => true;

  /// Initialize the pairing handler (keys).
  Future<void> initialize() async {
    await _handler.initialize();
    _logger.info('Pairing service initialized');
  }

  /// Get our public key for display.
  String get ourPublicKey => _handler.ourPublicKeyEncoded;

  /// Generate a QR code JSON string for our device info.
  String generateQrCodeJson({
    required String deviceName,
    int port = 8080,
  }) {
    final ip = '0.0.0.0'; // Will be resolved by scanner
    final payload = _handler.generateQrPayload(
      deviceName: deviceName,
      ipAddress: ip,
      port: port,
    );
    return jsonEncode(payload.toJson());
  }

  /// Generate a QR code JSON string with actual local IP.
  Future<String> generateQrCodeJsonWithIp({
    required String deviceName,
    int port = 8080,
  }) async {
    final ip = await NetworkUtils.getLocalIp() ?? '0.0.0.0';
    final payload = _handler.generateQrPayload(
      deviceName: deviceName,
      ipAddress: ip,
      port: port,
    );
    return jsonEncode(payload.toJson());
  }

  /// Verify and process a scanned QR code.
  Future<QrPairingPayload?> verifyQrCode(String jsonStr) async {
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return _handler.verifyQrPayload(json);
    } catch (e) {
      _logger.error('Failed to parse QR code', e);
      return null;
    }
  }

  /// Generate the confirmation code shown on both screens.
  String generateConfirmationCode(String peerPublicKey) {
    return _handler.generatePairingCode(peerPublicKey);
  }

  /// Complete the pairing and save the trusted device.
  Future<Device> completePairing(QrPairingPayload peerPayload) async {
    return _handler.completePairing(peerPayload: peerPayload);
  }

  /// Get all paired devices.
  Future<List<Device>> getPairedDevices() async {
    return _deviceRepository.getPairedDevices();
  }

  /// Remove a paired device.
  Future<void> unpairDevice(String id) async {
    await _deviceRepository.removeDevice(id);
    _logger.info('Device unpaired: $id');
  }
}
