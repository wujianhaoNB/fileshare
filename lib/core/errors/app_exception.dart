/// Base exception class for all application errors.
abstract class AppException implements Exception {
  String get userMessage;
  String get technicalMessage;
}

enum NetworkErrorType {
  timeout,
  unreachable,
  connectionReset,
  dnsResolution,
  portBlocked,
}

class NetworkException extends AppException {
  NetworkException(this.type, {this.details});

  final NetworkErrorType type;
  final String? details;

  @override
  String get userMessage {
    switch (type) {
      case NetworkErrorType.timeout:
        return 'Connection timed out. Please check your network.';
      case NetworkErrorType.unreachable:
        return 'Device is unreachable. Make sure both devices are on the same network.';
      case NetworkErrorType.connectionReset:
        return 'Connection was interrupted. You can resume the transfer.';
      case NetworkErrorType.dnsResolution:
        return 'Could not resolve device address.';
      case NetworkErrorType.portBlocked:
        return 'Connection blocked by firewall. Please allow FileShare in your firewall settings.';
    }
  }

  @override
  String get technicalMessage => 'NetworkException($type): ${details ?? ""}';
}

enum TransferErrorType {
  fileNotFound,
  diskFull,
  hashMismatch,
  permissionDenied,
  cancelled,
  unknown,
}

class TransferException extends AppException {
  TransferException(this.type, {this.details});

  final TransferErrorType type;
  final String? details;

  @override
  String get userMessage {
    switch (type) {
      case TransferErrorType.fileNotFound:
        return 'File not found. It may have been moved or deleted.';
      case TransferErrorType.diskFull:
        return 'Not enough storage space. Please free up space and try again.';
      case TransferErrorType.hashMismatch:
        return 'File verification failed. The file may be corrupted.';
      case TransferErrorType.permissionDenied:
        return 'Permission denied. Please grant storage access.';
      case TransferErrorType.cancelled:
        return 'Transfer was cancelled.';
      case TransferErrorType.unknown:
        return 'An unexpected error occurred during transfer.';
    }
  }

  @override
  String get technicalMessage => 'TransferException($type): ${details ?? ""}';
}

enum SecurityErrorType {
  signatureInvalid,
  replayDetected,
  untrustedDevice,
  keyExchangeFailed,
}

class SecurityException extends AppException {
  SecurityException(this.type, {this.details});

  final SecurityErrorType type;
  final String? details;

  @override
  String get userMessage {
    switch (type) {
      case SecurityErrorType.signatureInvalid:
        return 'QR code verification failed. Make sure you are scanning the correct code.';
      case SecurityErrorType.replayDetected:
        return 'Security warning: possible replay attack detected.';
      case SecurityErrorType.untrustedDevice:
        return 'This device is not trusted. Please pair first.';
      case SecurityErrorType.keyExchangeFailed:
        return 'Secure connection could not be established.';
    }
  }

  @override
  String get technicalMessage => 'SecurityException($type): ${details ?? ""}';
}
