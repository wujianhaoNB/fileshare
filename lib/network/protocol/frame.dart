import 'dart:typed_data';
import 'protocol_constants.dart';

/// Represents a single wire-protocol frame.
class Frame {
  final int messageType;
  final Uint8List payload;

  const Frame({
    required this.messageType,
    required this.payload,
  });

  /// Encode this frame to wire format bytes.
  Uint8List encode() {
    final header = ByteData(ProtocolConstants.frameHeaderSize);
    header.setUint32(0, ProtocolConstants.magic, Endian.big);
    header.setUint32(4, ProtocolConstants.version, Endian.big);
    header.setUint32(8, messageType, Endian.big);
    header.setUint32(12, payload.length, Endian.big);

    final result = Uint8List(ProtocolConstants.frameHeaderSize + payload.length);
    result.setRange(0, ProtocolConstants.frameHeaderSize, header.buffer.asUint8List());
    result.setRange(ProtocolConstants.frameHeaderSize, result.length, payload);
    return result;
  }

  /// Decode a frame from wire format bytes.
  /// Returns null if the magic bytes or version don't match.
  static Frame? decode(Uint8List data) {
    if (data.length < ProtocolConstants.frameHeaderSize) return null;

    final header = ByteData.sublistView(data, 0, ProtocolConstants.frameHeaderSize);
    final magic = header.getUint32(0, Endian.big);
    final version = header.getUint32(4, Endian.big);
    final msgType = header.getUint32(8, Endian.big);
    final payloadLen = header.getUint32(12, Endian.big);

    if (magic != ProtocolConstants.magic) return null;
    if (version != ProtocolConstants.version) return null;

    final payloadStart = ProtocolConstants.frameHeaderSize;
    if (data.length < payloadStart + payloadLen) return null;

    final payload = Uint8List.sublistView(data, payloadStart, payloadStart + payloadLen);

    return Frame(messageType: msgType, payload: payload);
  }
}

/// Utility for reading and writing frames from a stream.
class FrameReader {
  final _buffer = <int>[];
  int _expectedLength = ProtocolConstants.frameHeaderSize;
  bool _headerRead = false;

  /// Feed raw bytes into the reader. Returns complete frames as they are assembled.
  List<Frame> feed(Uint8List data) {
    final frames = <Frame>[];
    _buffer.addAll(data);

    while (true) {
      if (!_headerRead) {
        if (_buffer.length < ProtocolConstants.frameHeaderSize) break;

        final headerBytes = Uint8List.fromList(
          _buffer.sublist(0, ProtocolConstants.frameHeaderSize),
        );
        final header = ByteData.sublistView(headerBytes);
        final magic = header.getUint32(0, Endian.big);
        final version = header.getUint32(4, Endian.big);
        final payloadLen = header.getUint32(12, Endian.big);

        if (magic != ProtocolConstants.magic || version != ProtocolConstants.version) {
          // Skip one byte and try again (re-sync)
          _buffer.removeAt(0);
          continue;
        }

        _expectedLength = ProtocolConstants.frameHeaderSize + payloadLen;
        _headerRead = true;
      }

      if (_buffer.length < _expectedLength) break;

      final frameBytes = Uint8List.fromList(_buffer.sublist(0, _expectedLength));
      _buffer.removeRange(0, _expectedLength);
      _headerRead = false;
      _expectedLength = ProtocolConstants.frameHeaderSize;

      final frame = Frame.decode(frameBytes);
      if (frame != null) {
        frames.add(frame);
      }
    }

    return frames;
  }
}
