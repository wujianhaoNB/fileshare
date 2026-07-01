import 'dart:convert';
import 'frame.dart';
import 'message.dart';
import 'protocol_constants.dart';

/// Converts between ProtocolMessage objects and wire-format Frames.
class Serializer {
  /// Serialize a message to a frame.
  static Frame toFrame(ProtocolMessage message) {
    return Frame(
      messageType: _messageType(message),
      payload: message.encodePayload(),
    );
  }

  /// Deserialize a frame back into a typed message.
  static ProtocolMessage? fromFrame(Frame frame) {
    try {
      switch (frame.messageType) {
        case ProtocolConstants.msgMetadata:
          final json = jsonDecode(utf8.decode(frame.payload)) as Map<String, dynamic>;
          return MetadataMessage.fromJson(json);

        case ProtocolConstants.msgChunk:
          return ChunkMessage.decode(frame.payload);

        case ProtocolConstants.msgResumeRequest:
          final json = jsonDecode(utf8.decode(frame.payload)) as Map<String, dynamic>;
          return ResumeRequestMessage.fromJson(json);

        case ProtocolConstants.msgResumeAck:
          return ResumeAckMessage.decode(frame.payload);

        case ProtocolConstants.msgAck:
          return AckMessage.decode(frame.payload);

        case ProtocolConstants.msgCancel:
          final json = jsonDecode(utf8.decode(frame.payload)) as Map<String, dynamic>;
          return CancelMessage(reason: json['reason'] as String?);

        case ProtocolConstants.msgDone:
          return const DoneMessage();

        case ProtocolConstants.msgError:
          final json = jsonDecode(utf8.decode(frame.payload)) as Map<String, dynamic>;
          return ErrorMessage.fromJson(json);

        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  static int _messageType(ProtocolMessage message) {
    return switch (message) {
      MetadataMessage() => ProtocolConstants.msgMetadata,
      ChunkMessage() => ProtocolConstants.msgChunk,
      ResumeRequestMessage() => ProtocolConstants.msgResumeRequest,
      ResumeAckMessage() => ProtocolConstants.msgResumeAck,
      AckMessage() => ProtocolConstants.msgAck,
      CancelMessage() => ProtocolConstants.msgCancel,
      DoneMessage() => ProtocolConstants.msgDone,
      ErrorMessage() => ProtocolConstants.msgError,
    };
  }
}
