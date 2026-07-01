import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Utilities for file hashing.
class HashUtils {
  HashUtils._();

  static final _hashAlgorithm = Sha256();

  /// Compute SHA-256 hash of a file incrementally (streaming).
  static Future<Uint8List> hashFile(String path) async {
    final file = File(path);
    final hashSink = _hashAlgorithm.newHashSink();
    final raf = await file.open(mode: FileMode.read);
    try {
      final buffer = Uint8List(65536); // 64 KiB read buffer
      int bytesRead;
      while ((bytesRead = await raf.readInto(buffer)) > 0) {
        hashSink.addSlice(buffer, 0, bytesRead, false);
      }
      hashSink.close();
      final hash = await hashSink.hash();
      return Uint8List.fromList(hash.bytes);
    } finally {
      await raf.close();
    }
  }

  /// Compute SHA-256 hash of raw bytes.
  static Future<Uint8List> hashBytes(Uint8List data) async {
    final hash = await _hashAlgorithm.hash(data);
    return Uint8List.fromList(hash.bytes);
  }

  /// Verify that a file's hash matches the expected hash.
  static Future<bool> verifyHash(String path, Uint8List expectedHash) async {
    final actual = await hashFile(path);
    if (actual.length != expectedHash.length) return false;
    for (var i = 0; i < actual.length; i++) {
      if (actual[i] != expectedHash[i]) return false;
    }
    return true;
  }

  /// Convert hash bytes to hex string.
  static String toHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Generate a short fingerprint from hash bytes (first 4 bytes as hex).
  static String shortFingerprint(Uint8List bytes) {
    return toHex(bytes.sublist(0, 4)).toUpperCase();
  }
}
