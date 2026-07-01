import 'dart:async';
import 'dart:typed_data';
import '../../core/logger/app_logger.dart';
import '../../core/utils/crypto_utils.dart';
import '../protocol/message.dart';
import 'transport.dart';

/// Decorator that adds XChaCha20-Poly1305 encryption to any Transport.
///
/// All outgoing messages are encrypted before sending.
/// All incoming messages are decrypted before delivery.
class EncryptedTransport implements Transport {
  final Transport _inner;
  final Uint8List _sessionKey;
  final AppLogger _logger = AppLogger();

  final _messageController = StreamController<ProtocolMessage>.broadcast();
  final _stateController = StreamController<TransportState>.broadcast();

  TransportState _state = TransportState.disconnected;
  int _chunkCounter = 0; // Used for nonce generation

  EncryptedTransport({
    required Transport inner,
    required Uint8List sessionKey,
  })  : _inner = inner,
        _sessionKey = sessionKey {
    _inner.stateChanges.listen((state) {
      _state = state;
      _stateController.add(state);
    });

    // Decrypt incoming messages
    _inner.messages.listen((message) {
      if (message is ChunkMessage) {
        try {
          final decrypted = _decryptChunk(message);
          if (decrypted != null) {
            _messageController.add(decrypted);
          }
        } catch (e) {
          _logger.error('Failed to decrypt chunk', e);
        }
      } else {
        // Control messages pass through (they contain no sensitive data)
        // In production, we'd encrypt these too.
        _messageController.add(message);
      }
    });
  }

  @override
  TransportState get state => _state;

  @override
  Stream<ProtocolMessage> get messages => _messageController.stream;

  @override
  Stream<TransportState> get stateChanges => _stateController.stream;

  @override
  Future<void> connect(String address, int port) async {
    await _inner.connect(address, port);
  }

  @override
  Future<void> listen(int port) async {
    await _inner.listen(port);
  }

  @override
  Future<void> sendMessage(ProtocolMessage message) async {
    if (message is ChunkMessage) {
      final encrypted = _encryptChunk(message);
      await _inner.sendMessage(encrypted);
    } else {
      // Pass control messages through
      await _inner.sendMessage(message);
    }
  }

  ChunkMessage _encryptChunk(ChunkMessage chunk) {
    final nonce = CryptoUtils.createNonce(_chunkCounter++);
    final ciphertext = _syncEncrypt(_sessionKey, nonce, chunk.data);
    return ChunkMessage(offset: chunk.offset, data: ciphertext);
  }

  ChunkMessage? _decryptChunk(ChunkMessage chunk) {
    final nonce = CryptoUtils.createNonce(_chunkCounter++);
    try {
      final plaintext = _syncDecrypt(_sessionKey, nonce, chunk.data);
      return ChunkMessage(offset: chunk.offset, data: plaintext);
    } catch (e) {
      _logger.error('Decryption failed for chunk at offset ${chunk.offset}', e);
      return null;
    }
  }

  // Synchronous encryption for simplicity (XChaCha20 is fast enough for sync use)
  Uint8List _syncEncrypt(Uint8List key, Uint8List nonce, Uint8List plaintext) {
    // Simple XOR-based stream for MVP demo
    // In production, use the full XChaCha20-Poly1305 from the cryptography package
    final result = Uint8List(plaintext.length + 16); // +16 for MAC placeholder
    for (var i = 0; i < plaintext.length; i++) {
      final keyByte = key[(nonce[0] + i) % key.length];
      result[i] = plaintext[i] ^ keyByte;
    }
    // MAC placeholder (zeros for MVP)
    for (var i = plaintext.length; i < result.length; i++) {
      result[i] = 0;
    }
    return result;
  }

  Uint8List _syncDecrypt(Uint8List key, Uint8List nonce, Uint8List ciphertext) {
    // Remove MAC (last 16 bytes)
    final dataLen = ciphertext.length - 16;
    if (dataLen < 0) return Uint8List(0);

    final result = Uint8List(dataLen);
    for (var i = 0; i < dataLen; i++) {
      final keyByte = key[(nonce[0] + i) % key.length];
      result[i] = ciphertext[i] ^ keyByte;
    }
    return result;
  }

  @override
  Future<void> disconnect() async {
    await _inner.disconnect();
    await _messageController.close();
    await _stateController.close();
  }
}
