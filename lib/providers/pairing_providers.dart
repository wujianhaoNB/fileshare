import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/device.dart';
import '../network/pairing/pairing_handler.dart';
import 'service_providers.dart';

/// Current pairing state during the QR pairing flow.
enum PairingFlowState {
  idle,
  scanning,
  qrDetected,
  verifying,
  confirming,
  pairing,
  success,
  failed,
}

/// Pairing flow state.
final pairingFlowStateProvider = StateProvider<PairingFlowState>((ref) => PairingFlowState.idle);

/// Error message during pairing.
final pairingErrorProvider = StateProvider<String?>((ref) => null);

/// Scanned QR payload (verified).
final scannedPayloadProvider = StateProvider<QrPairingPayload?>((ref) => null);

/// Pairing confirmation code (4 chars shown on both screens).
final pairingCodeProvider = StateProvider<String>((ref) => '');

/// List of paired devices.
final pairedDevicesProvider = FutureProvider<List<Device>>((ref) async {
  final deviceRepo = ref.watch(deviceRepositoryProvider);
  return deviceRepo.getPairedDevices();
});
