import 'dart:async';
import '../protocol/message.dart';

/// Abstract interface for file transport (TCP, Bluetooth, etc.).
abstract class Transport {
  /// Connect to a remote device at [address]:[port].
  Future<void> connect(String address, int port);

  /// Start listening for incoming connections on [port].
  Future<void> listen(int port);

  /// Send a typed protocol message.
  Future<void> sendMessage(ProtocolMessage message);

  /// Stream of incoming messages from the connected peer.
  Stream<ProtocolMessage> get messages;

  /// Stream of connection state changes.
  Stream<TransportState> get stateChanges;

  /// Current connection state.
  TransportState get state;

  /// Disconnect gracefully.
  Future<void> disconnect();
}

enum TransportState {
  disconnected,
  connecting,
  connected,
  error,
}
