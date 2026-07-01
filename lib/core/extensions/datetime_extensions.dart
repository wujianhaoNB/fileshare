/// Human-readable formatting for DateTime values.
extension DateTimeFormat on DateTime {
  /// Returns a relative time string (e.g., "5m ago", "2h ago", "yesterday").
  String get relativeTime {
    final now = DateTime.now();
    final diff = now.difference(this);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  /// Returns a concise time string (e.g., "14:30" or "Jan 5").
  String get shortFormat {
    final now = DateTime.now();
    if (year == now.year && month == now.month && day == now.day) {
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    }
    return '$month/$day';
  }
}
