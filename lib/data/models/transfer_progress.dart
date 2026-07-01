/// Live transfer progress state used during active transfers.
class TransferProgress {
  final String transferId;
  final String fileName;
  final int fileSize;
  final int bytesTransferred;
  final double speedBytesPerSecond;
  final String peerName;
  final bool isIncoming;
  final TransferProgressState state;
  final String? error;

  const TransferProgress({
    required this.transferId,
    required this.fileName,
    required this.fileSize,
    this.bytesTransferred = 0,
    this.speedBytesPerSecond = 0,
    required this.peerName,
    this.isIncoming = false,
    this.state = TransferProgressState.transferring,
    this.error,
  });

  double get progress =>
      fileSize > 0 ? bytesTransferred / fileSize : 0.0;

  int get remainingBytes => fileSize - bytesTransferred;

  String get speedFormatted {
    if (speedBytesPerSecond < 1024) return '${speedBytesPerSecond.toStringAsFixed(0)} B/s';
    if (speedBytesPerSecond < 1024 * 1024) {
      return '${(speedBytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(speedBytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  String get remainingTimeFormatted {
    if (speedBytesPerSecond <= 0 || remainingBytes <= 0) return '--';
    final seconds = remainingBytes ~/ speedBytesPerSecond;
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m ${seconds % 60}s';
    return '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';
  }

  TransferProgress copyWith({
    int? bytesTransferred,
    double? speedBytesPerSecond,
    TransferProgressState? state,
    String? error,
  }) {
    return TransferProgress(
      transferId: transferId,
      fileName: fileName,
      fileSize: fileSize,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      speedBytesPerSecond: speedBytesPerSecond ?? this.speedBytesPerSecond,
      peerName: peerName,
      isIncoming: isIncoming,
      state: state ?? this.state,
      error: error,
    );
  }
}

enum TransferProgressState {
  connecting,
  transferring,
  paused,
  completing,
  completed,
  failed,
  cancelled,
}
