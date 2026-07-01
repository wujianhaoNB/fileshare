/// Represents a transfer record (history entry).
class TransferRecord {
  final String id;
  final String peerId;
  final TransferDirection direction;
  final String fileName;
  final int fileSize;
  final String? mimeType;
  final String? sha256Hash;
  final String? filePath;
  final TransferStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int bytesTransferred;
  final TransferTransport transport;
  final String? errorMessage;

  const TransferRecord({
    required this.id,
    required this.peerId,
    required this.direction,
    required this.fileName,
    required this.fileSize,
    this.mimeType,
    this.sha256Hash,
    this.filePath,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.bytesTransferred = 0,
    this.transport = TransferTransport.tcp,
    this.errorMessage,
  });

  double get progress =>
      fileSize > 0 ? bytesTransferred / fileSize : 0.0;

  bool get isActive =>
      status == TransferStatus.inProgress || status == TransferStatus.paused;

  bool get isComplete =>
      status == TransferStatus.completed;

  bool get canResume =>
      status == TransferStatus.paused;
}

enum TransferDirection { outgoing, incoming }

enum TransferStatus { pending, inProgress, completed, paused, failed, cancelled }

enum TransferTransport { tcp, bluetooth, relay }
