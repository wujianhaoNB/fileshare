/// Application-wide constants for the file transfer protocol.
class AppConstants {
  AppConstants._();

  // --- Service Discovery ---
  static const String serviceType = '_fileshare._tcp';
  static const String serviceDomain = 'local';
  static const int defaultControlPort = 8080;
  static const int defaultDataPort = 9876;
  static const int discoveryTimeoutMs = 5000;
  static const Duration subnetScanTimeout = Duration(milliseconds: 200);

  // --- Protocol ---
  static const int protocolMagic = 0x464C4545;
  static const int protocolVersion = 1;
  static const int chunkSize = 65536; // 64 KiB
  static const int maxInFlightChunks = 16;
  static const int ackIntervalChunks = 16;
  static const Duration statePersistInterval = Duration(seconds: 30);

  // --- Message Types ---
  static const int msgTypeMetadata = 0x01;
  static const int msgTypeChunk = 0x02;
  static const int msgTypeResumeReq = 0x03;
  static const int msgTypeResumeAck = 0x04;
  static const int msgTypeCancel = 0x05;
  static const int msgTypeDone = 0x06;
  static const int msgTypeError = 0x07;
  static const int msgTypeAck = 0x08;

  // --- Crypto ---
  static const String hkdfInfo = 'fileshare-session-v1';
  static const int nonceSize = 12;
  static const int pairingCodeLength = 4;

  // --- Temp files ---
  static const Duration tempFileRetention = Duration(days: 7);

  // --- UI ---
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration transferSpeedUpdateInterval = Duration(milliseconds: 500);
}
