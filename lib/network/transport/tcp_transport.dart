import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import '../protocol/frame.dart';
import '../protocol/message.dart';
import '../protocol/serializer.dart';
import 'transport.dart';
import '../../core/logger/app_logger.dart';

/// TCP implementation of the Transport interface using the binary frame protocol.
class TcpTransport implements Transport {
  final AppLogger _logger = AppLogger();
  Socket? _socket;
  ServerSocket? _serverSocket;
  final FrameReader _frameReader = FrameReader();

  final _messageController = StreamController<ProtocolMessage>.broadcast();
  final _stateController = StreamController<TransportState>.broadcast();

  TransportState _state = TransportState.disconnected;

  @override
  TransportState get state => _state;

  @override
  Stream<ProtocolMessage> get messages => _messageController.stream;

  @override
  Stream<TransportState> get stateChanges => _stateController.stream;

  void _setState(TransportState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }

  /// Connect to a remote device as a client.
  @override
  Future<void> connect(String address, int port) async {
    _setState(TransportState.connecting);
    try {
      _socket = await Socket.connect(
        address,
        port,
        timeout: const Duration(seconds: 10),
      );
      _setState(TransportState.connected);
      _logger.info('TCP connected to $address:$port');

      _socket!.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
    } catch (e) {
      _setState(TransportState.error);
      _logger.error('TCP connection failed to $address:$port', e);
      rethrow;
    }
  }

  /// Start listening as a server.
  @override
  Future<void> listen(int port) async {
    _setState(TransportState.connecting);
    try {
      _serverSocket = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        port,
        backlog: 5,
      );
      _setState(TransportState.connected);
      _logger.info('TCP server listening on port $port');

      _serverSocket!.listen(
        (Socket client) {
          _socket = client;
          _logger.info('TCP client connected: ${client.remoteAddress.address}:${client.remotePort}');

          client.listen(
            _onData,
            onError: _onError,
            onDone: _onDone,
            cancelOnError: false,
          );
        },
        onError: _onServerError,
      );
    } catch (e) {
      _setState(TransportState.error);
      _logger.error('Failed to bind TCP server on port $port', e);
      rethrow;
    }
  }

  /// Send a protocol message to the connected peer.
  @override
  Future<void> sendMessage(ProtocolMessage message) async {
    if (_socket == null) {
      throw StateError('Not connected');
    }

    final frame = Serializer.toFrame(message);
    final bytes = frame.encode();

    try {
      _socket!.add(bytes);
      await _socket!.flush();
    } catch (e) {
      _logger.error('Failed to send message', e);
      _setState(TransportState.error);
      rethrow;
    }
  }

  /// Send raw bytes (for chunk data bypassing the message layer).
  Future<void> sendRaw(Uint8List data) async {
    if (_socket == null) throw StateError('Not connected');
    _socket!.add(data);
    await _socket!.flush();
  }

  void _onData(Uint8List data) {
    final frames = _frameReader.feed(data);
    for (final frame in frames) {
      final message = Serializer.fromFrame(frame);
      if (message != null) {
        _messageController.add(message);
      }
    }
  }

  void _onError(Object error) {
    _logger.error('TCP transport error', error);
    _setState(TransportState.error);
  }

  void _onDone() {
    _logger.info('TCP connection closed by peer');
    _setState(TransportState.disconnected);
  }

  void _onServerError(Object error) {
    _logger.error('TCP server error', error);
    _setState(TransportState.error);
  }

  @override
  Future<void> disconnect() async {
    try {
      await _socket?.close();
      await _serverSocket?.close();
    } catch (e) {
      _logger.error('Error during disconnect', e);
    }
    _socket = null;
    _serverSocket = null;
    _setState(TransportState.disconnected);
    _logger.info('TCP transport disconnected');
  }

  /// Clean up all resources.
  Future<void> dispose() async {
    await disconnect();
    await _messageController.close();
    await _stateController.close();
  }
}
