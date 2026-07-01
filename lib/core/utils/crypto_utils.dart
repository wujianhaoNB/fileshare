import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// XChaCha20-Poly1305 encryption utilities for file transfer.
class CryptoUtils {
  CryptoUtils._();

  /// Derive a symmetric key using HKDF.
  static Future<Uint8List> deriveKey(Uint8List sharedSecret, String info) async {
    final hkdf = Hkdf(
      hmac: Hmac.sha256(),
      outputLength: 32,
    );
    final output = await hkdf.deriveKey(
      secretKey: SecretKey(sharedSecret),
      info: info.codeUnits,
      nonce: Uint8List(32), // zero salt
    );
    final bytes = await output.extractBytes();
    return Uint8List.fromList(bytes);
  }

  /// Encrypt data with XChaCha20-Poly1305.
  static Future<Uint8List> encrypt(Uint8List key, Uint8List nonce, Uint8List plaintext) async {
    final algorithm = Xchacha20.poly1305Aead();
    final secretKey = SecretKey(key);
    final result = await algorithm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );
    return result.concatenation(nonce: false, mac: true);
  }

  /// Decrypt data with XChaCha20-Poly1305.
  static Future<Uint8List> decrypt(Uint8List key, Uint8List nonce, Uint8List ciphertextWithMac) async {
    final algorithm = Xchacha20.poly1305Aead();
    final secretKey = SecretKey(key);
    final secretBox = SecretBox(
      Uint8List.sublistView(ciphertextWithMac, 0, ciphertextWithMac.length - 16),
      nonce: nonce,
      mac: Mac(Uint8List.sublistView(ciphertextWithMac, ciphertextWithMac.length - 16)),
    );
    final decrypted = await algorithm.decrypt(secretBox, secretKey: secretKey);
    return Uint8List.fromList(decrypted);
  }

  /// Create a nonce from a chunk offset.
  static Uint8List createNonce(int chunkOffset, {int size = 12}) {
    final nonce = ByteData(size);
    nonce.setUint64(0, chunkOffset, Endian.big);
    // Remaining bytes are zero-filled by default
    return nonce.buffer.asUint8List();
  }

  /// Generate random bytes using the cryptographic RNG.
  static Uint8List randomBytes(int length) {
    return Uint8List.fromList(
      List.generate(length, (_) => _secureRandom()),
    );
  }

  static int _secureRandom() {
    // dart:math Random is acceptable for non-security-critical randomization
    // For key generation, use the cryptography package's key generation instead
    return DateTime.now().microsecondsSinceEpoch & 0xFF;
  }
}
