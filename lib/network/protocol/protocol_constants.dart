/// Low-level protocol constants for the binary wire format.
class ProtocolConstants {
  ProtocolConstants._();

  // Magic bytes: "FLEE" in ASCII
  static const int magic = 0x464C4545;
  static const int version = 1;

  // Message types
  static const int msgMetadata = 0x01;
  static const int msgChunk = 0x02;
  static const int msgResumeRequest = 0x03;
  static const int msgResumeAck = 0x04;
  static const int msgCancel = 0x05;
  static const int msgDone = 0x06;
  static const int msgError = 0x07;
  static const int msgAck = 0x08;

  // Frame header size: magic(4) + version(4) + msgType(4) + payloadLen(4)
  static const int frameHeaderSize = 16;

  // Transport
  static const int chunkSize = 65536; // 64 KiB
  static const int maxInFlightChunks = 16;
}
