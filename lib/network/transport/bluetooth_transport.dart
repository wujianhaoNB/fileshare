import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../protocol/frame.dart';
import '../protocol/message.dart';
import '../protocol/serializer.dart';
import '../protocol/protocol_constants.dart';
import 'transport.dart';
import '../../core/logger/app_logger.dart';

/// Bluetooth Low Energy (GATT) implementation of the Transport interface.
///
/// Architecture:
/// - One device acts as GATT server (advertises), the other as GATT client (connects).
/// - Two characteristics:
///   * Control characteristic (UUID: 2A00-xxxx)  — JSON control messages
///   * Data characteristic (UUID: 2A01-xxxx)     — Binary chunk data
/// - Chunks are fragmented across multiple GATT writes (MTU-sized).
/// - Receiver reassembles using chunk header's offset + length.
class BluetoothTransport implements Transport {
  final AppLogger _logger = AppLogger();

  // Custom service UUIDs
  static final _serviceUuid = Guid('12345678-1234-1234-1234-123456789abc');
  static final _controlCharUuid = Guid('12345678-1234-1234-1234-123456789abd');
  static final _dataCharUuid = Guid('12345678-1234-1234-1234-123456789abe');

  BluetoothDevice? _device;
  BluetoothCharacteristic? _controlChar;
  BluetoothCharacteristic? _dataChar;

  final _messageController = StreamController<ProtocolMessage>.broadcast();
  final _stateController = StreamController<TransportState>.broadcast();

  TransportState _state = TransportState.disconnected;
  StreamSubscription? _controlSubscription;
  StreamSubscription? _dataSubscription;

  // Reassembly buffer for chunk data (MTU fragmentation)
  final _chunkBuffer = <int>[];

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

  /// Connect to a remote BLE device (client mode).
  @override
  Future<void> connect(String address, int port) async {
    _setState(TransportState.connecting);

    try {
      _device = BluetoothDevice(remoteId: DeviceIdentifier(address));

      await _device!.connect(timeout: const Duration(seconds: 15));
      _logger.info('BLE connected to $address');

      // Discover services
      final services = await _device!.discoverServices();

      for (final service in services) {
        if (service.uuid == _serviceUuid) {
          for (final char in service.characteristics) {
            if (char.uuid == _controlCharUuid) {
              _controlChar = char;
              await _controlChar!.setNotifyValue(true);
              _controlSubscription = _controlChar!.onValueReceived.listen(_onControlData);
            } else if (char.uuid == _dataCharUuid) {
              _dataChar = char;
              await _dataChar!.setNotifyValue(true);
              _dataSubscription = _dataChar!.onValueReceived.listen(_onDataReceived);
            }
          }
        }
      }

      if (_controlChar == null || _dataChar == null) {
        throw Exception('Required BLE characteristics not found');
      }

      // Request higher MTU
      await _device!.requestMtu(512);

      _setState(TransportState.connected);
      _logger.info('BLE transport ready: control + data characteristics');
    } catch (e) {
      _setState(TransportState.error);
      _logger.error('BLE connection failed', e);
      rethrow;
    }
  }

  /// BLE server mode is not supported in this version of flutter_blue_plus.
  /// Use TCP transport for server/listen mode, or connect as a BLE client.
  @override
  Future<void> listen(int port) async {
    _setState(TransportState.error);
    _logger.error('BLE server/advertising mode not supported. Use TCP transport or BLE client mode.');
    throw UnsupportedError('BLE server mode not available in this flutter_blue_plus version');
  }

  void _onControlData(List<int> value) {
    try {
      final jsonStr = utf8.decode(value);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final msgType = json['mt'] as int;
      final payloadStr = json['p'] as String? ?? '';

      final payload = payloadStr.isNotEmpty
          ? Uint8List.fromList(base64Decode(payloadStr))
          : Uint8List(0);

      final frame = Frame(messageType: msgType, payload: payload);
      final message = Serializer.fromFrame(frame);
      if (message != null) {
        _messageController.add(message);
      }
    } catch (e) {
      _logger.debug('Failed to decode BLE control message: $e');
    }
  }

  void _onDataReceived(List<int> value) {
    // BLE data arrives in MTU-sized fragments.
    // We need to reassemble into complete frames.
    _chunkBuffer.addAll(value);

    // Try to extract complete frames from the buffer
    while (true) {
      if (_chunkBuffer.length < ProtocolConstants.frameHeaderSize) break;

      final headerBytes = Uint8List.fromList(
        _chunkBuffer.sublist(0, ProtocolConstants.frameHeaderSize),
      );
      final header = ByteData.sublistView(headerBytes);
      final magic = header.getUint32(0, Endian.big);
      final payloadLen = header.getUint32(12, Endian.big);

      if (magic != ProtocolConstants.magic) {
        // Skip one byte to re-sync
        _chunkBuffer.removeAt(0);
        continue;
      }

      final totalLen = ProtocolConstants.frameHeaderSize + payloadLen;
      if (_chunkBuffer.length < totalLen) break;

      final frameBytes = Uint8List.fromList(_chunkBuffer.sublist(0, totalLen));
      _chunkBuffer.removeRange(0, totalLen);

      final frame = Frame.decode(frameBytes);
      if (frame != null) {
        final message = Serializer.fromFrame(frame);
        if (message != null) {
          _messageController.add(message);
        }
      }
    }
  }

  /// Send a protocol message via BLE.
  @override
  Future<void> sendMessage(ProtocolMessage message) async {
    final frame = Serializer.toFrame(message);

    // Control messages (metadata, ack, cancel, done, error) go via control characteristic as JSON
    if (_isControlMessage(message)) {
      final json = jsonEncode({
        'mt': frame.messageType,
        'p': base64Encode(frame.payload),
      });
      await _writeControl(Uint8List.fromList(utf8.encode(json)));
    } else {
      // Data chunks go via data characteristic as raw binary frames
      final encoded = frame.encode();

      // Fragment into MTU-sized writes
      final mtu = _device?.mtuNow ?? 20;
      final maxWriteSize = mtu - 3; // GATT header overhead
      var offset = 0;

      while (offset < encoded.length) {
        final end = (offset + maxWriteSize).clamp(0, encoded.length);
        await _writeData(Uint8List.sublistView(encoded, offset, end));
        offset = end;
      }
    }
  }

  bool _isControlMessage(ProtocolMessage message) {
    return message is MetadataMessage ||
        message is ResumeRequestMessage ||
        message is ResumeAckMessage ||
        message is AckMessage ||
        message is CancelMessage ||
        message is DoneMessage ||
        message is ErrorMessage;
  }

  Future<void> _writeControl(Uint8List data) async {
    if (_controlChar == null) throw StateError('Control characteristic not available');
    await _controlChar!.write(data, withoutResponse: false);
  }

  Future<void> _writeData(Uint8List data) async {
    if (_dataChar == null) throw StateError('Data characteristic not available');
    await _dataChar!.write(data, withoutResponse: true);
  }

  @override
  Future<void> disconnect() async {
    try {
      _controlSubscription?.cancel();
      _dataSubscription?.cancel();
      await _device?.disconnect();
    } catch (e) {
      _logger.error('BLE disconnect error', e);
    }

    _device = null;
    _controlChar = null;
    _dataChar = null;
    _chunkBuffer.clear();
    _setState(TransportState.disconnected);
    _logger.info('BLE transport disconnected');
  }

  /// Scan for nearby FileShare BLE devices.
  static Stream<List<ScanResult>> scanForDevices() {
    FlutterBluePlus.startScan(
      withServices: [_serviceUuid],
      timeout: const Duration(seconds: 10),
    );
    return FlutterBluePlus.scanResults;
  }

  /// Stop BLE scanning.
  static Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  /// Cleanup.
  Future<void> dispose() async {
    await disconnect();
    await _messageController.close();
    await _stateController.close();
  }
}
