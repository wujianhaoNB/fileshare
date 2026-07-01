import 'package:flutter/material.dart';
import '../../core/extensions/file_extensions.dart';
import '../../data/models/transfer_progress.dart';

/// A tile showing a single transfer's progress.
class TransferProgressTile extends StatelessWidget {
  final TransferProgress progress;

  const TransferProgressTile({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  progress.isIncoming ? Icons.download : Icons.upload,
                  size: 20,
                  color: _statusColor(colorScheme),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    progress.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                Text(
                  progress.fileSize.formatFileSize,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${progress.isIncoming ? "来自" : "发往"} ${progress.peerName}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                if (progress.state == TransferProgressState.transferring) ...[
                  const Spacer(),
                  Text(
                    progress.speedFormatted,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                        ),
                  ),
                ],
              ],
            ),
            if (progress.state == TransferProgressState.transferring) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress.progress,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(progress.progress * 100).toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Text(
                    progress.remainingTimeFormatted,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ],
            if (progress.state == TransferProgressState.completed) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: 1.0, color: Colors.green),
            ],
            if (progress.state == TransferProgressState.failed) ...[
              const SizedBox(height: 8),
              Text(
                progress.error ?? '传输失败',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(ColorScheme colorScheme) {
    switch (progress.state) {
      case TransferProgressState.transferring:
        return colorScheme.primary;
      case TransferProgressState.completed:
        return Colors.green;
      case TransferProgressState.failed:
        return colorScheme.error;
      case TransferProgressState.cancelled:
        return Colors.orange;
      default:
        return colorScheme.onSurfaceVariant;
    }
  }
}
