import 'dart:typed_data';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

/// Ed25519 key management utilities for device identity and QR pairing.
class KeyUtils {
  KeyUtils._();

  /// Generate a new Ed25519 key pair.
  static ({Uint8List publicKey, Uint8List privateKey}) generateKeyPair() {
    final keyPair = ed.generateKey();
    return (
      publicKey: Uint8List.fromList(keyPair.publicKey.bytes),
      privateKey: Uint8List.fromList(keyPair.privateKey.bytes),
    );
  }

  /// Sign a message with an Ed25519 private key.
  static Uint8List sign(Uint8List privateKey, Uint8List message) {
    return ed.sign(ed.PrivateKey(privateKey), message);
  }

  /// Verify an Ed25519 signature.
  static bool verify(Uint8List publicKey, Uint8List message, Uint8List signature) {
    return ed.verify(ed.PublicKey(publicKey), message, signature);
  }

  /// Encode a public key as a base64url string (for QR codes).
  static String encodePublicKey(Uint8List publicKey) {
    return _base64UrlEncode(publicKey);
  }

  /// Decode a public key from a base64url string.
  static Uint8List decodePublicKey(String encoded) {
    return _base64UrlDecode(encoded);
  }

  /// Simple base64url encode (no padding).
  static String _base64UrlEncode(Uint8List bytes) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
    final buffer = StringBuffer();
    var value = 0;
    var bits = 0;

    for (final byte in bytes) {
      value = (value << 8) | byte;
      bits += 8;
      while (bits >= 6) {
        bits -= 6;
        buffer.write(chars[(value >> bits) & 0x3F]);
      }
    }
    if (bits > 0) {
      buffer.write(chars[(value << (6 - bits)) & 0x3F]);
    }
    return buffer.toString();
  }

  /// Simple base64url decode.
  static Uint8List _base64UrlDecode(String input) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
    final lookup = <String, int>{};
    for (var i = 0; i < chars.length; i++) {
      lookup[chars[i]] = i;
    }

    final bytes = <int>[];
    var value = 0;
    var bits = 0;

    for (final char in input.split('')) {
      final idx = lookup[char];
      if (idx == null) continue;
      value = (value << 6) | idx;
      bits += 6;
      if (bits >= 8) {
        bits -= 8;
        bytes.add((value >> bits) & 0xFF);
      }
    }
    return Uint8List.fromList(bytes);
  }
}
