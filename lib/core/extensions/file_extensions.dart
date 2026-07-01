/// Human-readable formatting for file-related values.
extension FileSizeFormat on int {
  /// Formats bytes into a human-readable string (e.g., "1.5 GB").
  String get formatFileSize {
    if (this < 1024) return '$this B';
    if (this < 1024 * 1024) return '${(this / 1024).toStringAsFixed(1)} KB';
    if (this < 1024 * 1024 * 1024) {
      return '${(this / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(this / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// MIME type detection from file extension.
extension FileMimeType on String {
  String get mimeType {
    final ext = this.toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.avi':
        return 'video/x-msvideo';
      case '.mp3':
        return 'audio/mpeg';
      case '.wav':
        return 'audio/wav';
      case '.pdf':
        return 'application/pdf';
      case '.doc':
      case '.docx':
        return 'application/msword';
      case '.zip':
        return 'application/zip';
      case '.tar':
        return 'application/x-tar';
      case '.gz':
        return 'application/gzip';
      case '.apk':
        return 'application/vnd.android.package-archive';
      case '.ipa':
        return 'application/octet-stream';
      default:
        return 'application/octet-stream';
    }
  }
}
