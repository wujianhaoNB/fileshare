import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/extensions/file_extensions.dart';
import '../../core/extensions/datetime_extensions.dart';
import '../../data/models/transfer_record.dart';
import '../../providers/transfer_providers.dart';
import '../widgets/empty_state.dart';

/// Screen showing transfer history.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(transferHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录'),
      ),
      body: historyAsync.when(
        data: (records) {
          if (records.isEmpty) {
            return const EmptyState(
              icon: Icons.history,
              title: '暂无传输记录',
              subtitle: '传输过的文件会显示在这里',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              return _HistoryTile(record: record);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('错误: $error')),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final TransferRecord record;

  const _HistoryTile({required this.record});

  IconData get _statusIcon {
    switch (record.status) {
      case TransferStatus.completed:
        return Icons.check_circle;
      case TransferStatus.failed:
        return Icons.error;
      case TransferStatus.cancelled:
        return Icons.cancel;
      case TransferStatus.paused:
        return Icons.pause_circle;
      default:
        return Icons.hourglass_bottom;
    }
  }

  Color _statusColor(BuildContext context) {
    switch (record.status) {
      case TransferStatus.completed:
        return Colors.green;
      case TransferStatus.failed:
        return Theme.of(context).colorScheme.error;
      case TransferStatus.cancelled:
        return Colors.orange;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          record.direction == TransferDirection.outgoing
              ? Icons.upload
              : Icons.download,
          color: _statusColor(context),
        ),
        title: Text(
          record.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${record.fileSize.formatFileSize} • ${record.startedAt.relativeTime}',
        ),
        trailing: Icon(
          _statusIcon,
          color: _statusColor(context),
          size: 20,
        ),
      ),
    );
  }
}
