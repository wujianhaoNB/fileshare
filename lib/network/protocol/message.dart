import 'dart:convert';
import 'dart:typed_data';

/// Strongly-typed messages that map to/from wire frames.
sealed class ProtocolMessage {
  /// Encode this message into a frame payload.
  Uint8List encodePayload();
}

/// Metadata sent before file transfer begins.
class MetadataMessage implements ProtocolMessage {
  final String fileName;
  final int fileSize;
  final String? fileHash; // hex-encoded SHA-256
  final int chunkSize;
  final String mimeType;

  const MetadataMessage({
    required this.fileName,
    required this.fileSize,
    this.fileHash,
    this.chunkSize = 65536,
    this.mimeType = 'application/octet-stream',
  });

  @override
  Uint8List encodePayload() {
    final json = {
      'file_name': fileName,
      'file_size': fileSize,
      'file_hash': fileHash,
      'chunk_size': chunkSize,
      'mime_type': mimeType,
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(json)));
  }

  factory MetadataMessage.fromJson(Map<String, dynamic> json) {
    return MetadataMessage(
      fileName: json['file_name'] as String,
      fileSize: json['file_size'] as int,
      fileHash: json['file_hash'] as String?,
      chunkSize: json['chunk_size'] as int? ?? 65536,
      mimeType: json['mime_type'] as String? ?? 'application/octet-stream',
    );
  }
}

/// A single chunk of file data.
class ChunkMessage implements ProtocolMessage {
  final int offset;
  final Uint8List data;

  const ChunkMessage({required this.offset, required this.data});

  @override
  Uint8List encodePayload() {
    final header = ByteData(12);
    header.setUint64(0, offset, Endian.big);
    header.setUint32(8, data.length, Endian.big);
    final result = Uint8List(12 + data.length);
    result.setRange(0, 12, header.buffer.asUint8List());
    result.setRange(12, result.length, data);
    return result;
  }

  factory ChunkMessage.decode(Uint8List payload) {
    final header = ByteData.sublistView(payload, 0, 12);
    final offset = header.getUint64(0, Endian.big);
    final dataLen = header.getUint32(8, Endian.big);
    final data = Uint8List.sublistView(payload, 12, 12 + dataLen);
    return ChunkMessage(offset: offset, data: data);
  }
}

/// Request to resume from a specific offset.
class ResumeRequestMessage implements ProtocolMessage {
  final String fileName;
  final int savedBytes;

  const ResumeRequestMessage({
    required this.fileName,
    required this.savedBytes,
  });

  @override
  Uint8List encodePayload() {
    final json = {
      'file_name': fileName,
      'saved_bytes': savedBytes,
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(json)));
  }

  factory ResumeRequestMessage.fromJson(Map<String, dynamic> json) {
    return ResumeRequestMessage(
      fileName: json['file_name'] as String,
      savedBytes: json['saved_bytes'] as int,
    );
  }
}

/// Acknowledgement of a resume request.
class ResumeAckMessage implements ProtocolMessage {
  final int confirmedOffset;

  const ResumeAckMessage({required this.confirmedOffset});

  @override
  Uint8List encodePayload() {
    final header = ByteData(8);
    header.setUint64(0, confirmedOffset, Endian.big);
    return header.buffer.asUint8List();
  }

  factory ResumeAckMessage.decode(Uint8List payload) {
    final header = ByteData.sublistView(payload, 0, 8);
    return ResumeAckMessage(confirmedOffset: header.getUint64(0, Endian.big));
  }
}

/// Generic acknowledgement (flow control).
class AckMessage implements ProtocolMessage {
  final int ackedOffset;

  const AckMessage({required this.ackedOffset});

  @override
  Uint8List encodePayload() {
    final header = ByteData(8);
    header.setUint64(0, ackedOffset, Endian.big);
    return header.buffer.asUint8List();
  }

  factory AckMessage.decode(Uint8List payload) {
    final header = ByteData.sublistView(payload, 0, 8);
    return AckMessage(ackedOffset: header.getUint64(0, Endian.big));
  }
}

/// Cancel an active transfer.
class CancelMessage implements ProtocolMessage {
  final String? reason;

  const CancelMessage({this.reason});

  @override
  Uint8List encodePayload() {
    final json = {'reason': reason ?? 'Cancelled by user'};
    return Uint8List.fromList(utf8.encode(jsonEncode(json)));
  }
}

/// Signal transfer completion.
class DoneMessage implements ProtocolMessage {
  const DoneMessage();

  @override
  Uint8List encodePayload() => Uint8List(0);
}

/// Error during transfer.
class ErrorMessage implements ProtocolMessage {
  final String error;

  const ErrorMessage({required this.error});

  @override
  Uint8List encodePayload() {
    final json = {'error': error};
    return Uint8List.fromList(utf8.encode(jsonEncode(json)));
  }

  factory ErrorMessage.fromJson(Map<String, dynamic> json) {
    return ErrorMessage(error: json['error'] as String);
  }
}
