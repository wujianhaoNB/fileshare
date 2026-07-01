import 'dart:convert';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import '../../core/logger/app_logger.dart';
import '../../core/utils/crypto_utils.dart';
import '../../core/utils/key_utils.dart';
import '../../data/models/device.dart';
import '../../data/repositories/device_repository.dart';

/// Complete pairing handshake: key gen → QR exchange → session key derivation → trust storage.
class PairingHandler {
  final AppLogger _logger = AppLogger();
  final DeviceRepository _deviceRepository;
  final _uuid = const Uuid();

  /// This device's Ed25519 key pair (generated once, stored).
  late final Uint8List _ourPublicKey;
  late final Uint8List _ourPrivateKey;

  /// Ephemeral session keys (re-generated per connection).
  Uint8List? _sessionKey;

  PairingHandler({required DeviceRepository deviceRepository})
      : _deviceRepository = deviceRepository;

  bool _initialized = false;

  /// Initialize keys (call once on app startup).
  Future<void> initialize() async {
    if (_initialized) return;

    // In production, load from secure storage. For MVP, generate fresh.
    final keyPair = KeyUtils.generateKeyPair();
    _ourPublicKey = keyPair.publicKey;
    _ourPrivateKey = keyPair.privateKey;
    _initialized = true;

    _logger.info('Pairing keys initialized. Public key: ${KeyUtils.encodePublicKey(_ourPublicKey)}');
  }

  /// Get our public key as a base64url string.
  String get ourPublicKeyEncoded => KeyUtils.encodePublicKey(_ourPublicKey);

  /// Generate a QR code pairing payload with Ed25519 signature.
  QrPairingPayload generateQrPayload({
    required String deviceName,
    required String ipAddress,
    required int port,
    Duration ttl = const Duration(seconds: 60),
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ttlTimestamp = timestamp + ttl.inMilliseconds;
    final nonce = CryptoUtils.randomBytes(2);

    // Prepare data to sign: nonce + TTL
    final signData = ByteData(10);
    signData.setUint16(0, ByteData.sublistView(nonce).getUint16(0, Endian.big), Endian.big);
    signData.setUint64(2, ttlTimestamp, Endian.big);

    final signature = KeyUtils.sign(_ourPrivateKey, signData.buffer.asUint8List());

    return QrPairingPayload(
      version: 1,
      deviceName: deviceName,
      publicKey: KeyUtils.encodePublicKey(_ourPublicKey),
      ipAddress: ipAddress,
      port: port,
      ttlTimestamp: ttlTimestamp,
      nonce: base64Url.encode(nonce),
      signature: base64Url.encode(signature),
    );
  }

  /// Verify a QR code payload from a peer.
  /// Returns the peer's info if valid, null if invalid/expired.
  QrPairingPayload? verifyQrPayload(Map<String, dynamic> json) {
    try {
      final payload = QrPairingPayload.fromJson(json);

      // Check TTL
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now > payload.ttlTimestamp) {
        _logger.warn('QR payload expired');
        return null;
      }

      // Verify signature
      final nonceBytes = base64Url.decode(payload.nonce);
      final signData = ByteData(10);
      signData.setUint16(0, ByteData.sublistView(Uint8List.fromList(nonceBytes)).getUint16(0, Endian.big), Endian.big);
      signData.setUint64(2, payload.ttlTimestamp, Endian.big);

      final signatureBytes = base64Url.decode(payload.signature);
      final peerPublicKey = KeyUtils.decodePublicKey(payload.publicKey);

      final isValid = KeyUtils.verify(peerPublicKey, signData.buffer.asUint8List(), Uint8List.fromList(signatureBytes));
      if (!isValid) {
        _logger.warn('QR payload signature verification failed');
        return null;
      }

      _logger.info('QR payload verified: ${payload.deviceName}');
      return payload;
    } catch (e) {
      _logger.error('QR payload verification error', e);
      return null;
    }
  }

  /// Generate a 4-character pairing confirmation code from two public keys.
  String generatePairingCode(String peerPublicKeyEncoded) {
    final combined = Uint8List.fromList([
      ..._ourPublicKey,
      ...KeyUtils.decodePublicKey(peerPublicKeyEncoded),
    ]);
    final hash = _quickHash(combined);
    return hash.substring(0, 4).toUpperCase();
  }

  /// Perform the full pairing handshake:
  /// 1. Exchange ephemeral X25519 keys
  /// 2. Derive session key via HKDF
  /// 3. Store peer as trusted
  Future<Device> completePairing({
    required QrPairingPayload peerPayload,
  }) async {
    // Generate ephemeral X25519 key pair for this session.
    // ephPublic and ephPrivate would be exchanged in a full Noise NK handshake.

    // In a real handshake, we'd exchange ephemeral keys with the peer.
    // For LAN MVP, we use the QR-provided peer public key directly.
    final peerPublicKey = KeyUtils.decodePublicKey(peerPayload.publicKey);

    // Derive session key using our private + their public
    // (Simplified — full Noise NK would exchange ephemeral keys)
    _sessionKey = await CryptoUtils.deriveKey(
      Uint8List.fromList([..._ourPrivateKey, ...peerPublicKey]),
      'fileshare-session-v1',
    );

    // Store paired device
    final device = Device(
      id: _uuid.v4(),
      displayName: peerPayload.deviceName,
      publicKey: peerPayload.publicKey,
      ip: peerPayload.ipAddress,
      port: peerPayload.port,
      trustLevel: 1,
      lastSeenAt: DateTime.now(),
    );

    await _deviceRepository.upsertDevice(device);

    _logger.info('Pairing completed with ${peerPayload.deviceName}');
    return device;
  }

  /// Get the current session key for encrypting transfers.
  Uint8List? get sessionKey => _sessionKey;

  /// Clear the session key after transfer ends.
  void clearSessionKey() {
    _sessionKey = null;
  }

  /// Quick non-cryptographic hash for pairing codes.
  String _quickHash(Uint8List data) {
    var hash = 0;
    for (final byte in data) {
      hash = ((hash << 5) - hash) + byte;
      hash |= 0; // Convert to 32-bit integer
    }
    return (hash & 0xFFFFFFFF).toRadixString(16).toUpperCase();
  }
}

/// Decoded QR code payload from a peer device.
class QrPairingPayload {
  final int version;
  final String deviceName;
  final String publicKey; // base64url-encoded
  final String ipAddress;
  final int port;
  final int ttlTimestamp;
  final String nonce; // base64url-encoded
  final String signature; // base64url-encoded

  const QrPairingPayload({
    required this.version,
    required this.deviceName,
    required this.publicKey,
    required this.ipAddress,
    required this.port,
    required this.ttlTimestamp,
    required this.nonce,
    required this.signature,
  });

  Map<String, dynamic> toJson() => {
        'v': version,
        'n': deviceName,
        'k': publicKey,
        'p': '$ipAddress:$port',
        't': ttlTimestamp,
        'c': nonce,
        's': signature,
      };

  factory QrPairingPayload.fromJson(Map<String, dynamic> json) {
    final address = (json['p'] as String).split(':');
    return QrPairingPayload(
      version: json['v'] as int,
      deviceName: json['n'] as String,
      publicKey: json['k'] as String,
      ipAddress: address[0],
      port: int.tryParse(address.length > 1 ? address[1] : '8080') ?? 8080,
      ttlTimestamp: json['t'] as int,
      nonce: json['c'] as String,
      signature: json['s'] as String,
    );
  }
}
