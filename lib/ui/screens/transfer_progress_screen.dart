import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/transfer_progress.dart';
import '../../providers/transfer_providers.dart';
import '../widgets/transfer_tile.dart';
import '../widgets/empty_state.dart';

/// Screen showing active transfers and their progress.
class TransferProgressScreen extends ConsumerWidget {
  const TransferProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTransfersAsync = ref.watch(activeTransfersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('传输'),
      ),
      body: activeTransfersAsync.when(
        data: (transfers) {
          if (transfers.isEmpty) {
            return EmptyState(
              icon: Icons.swap_horiz,
              title: '暂无传输任务',
              subtitle: '选择一个设备并发送文件开始使用',
            );
          }

          final active = transfers.values.where(
            (t) => t.state == TransferProgressState.transferring ||
                t.state == TransferProgressState.connecting ||
                t.state == TransferProgressState.paused,
          ).toList();

          final recent = transfers.values.where(
            (t) => t.state == TransferProgressState.completed ||
                t.state == TransferProgressState.failed ||
                t.state == TransferProgressState.cancelled,
          ).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (active.isNotEmpty) ...[
                Text(
                  '进行中 (${active.length})',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 8),
                ...active.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TransferProgressTile(progress: t),
                )),
              ],
              if (recent.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  '最近',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                ...recent.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TransferProgressTile(progress: t),
                )),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('错误: $error')),
      ),
    );
  }
}
