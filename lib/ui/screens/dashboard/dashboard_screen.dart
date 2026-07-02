import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/ai_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../providers/service_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final memoryStats = ref.watch(memoryStatsProvider);
    final meshDevices = ref.watch(meshDevicesProvider);
    final isRunning = ref.watch(isServerRunningProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('仪表盘'),
        actions: [
          if (!isRunning)
            TextButton.icon(
              onPressed: () async {
                final ds = ref.read(discoveryServiceProvider);
                final sm = ref.read(serverManagerProvider);
                final fm = ref.read(fileManagerProvider);
                await fm.init();
                await sm.start(deviceName: ref.read(deviceNameProvider));
                await ds.start(deviceName: ref.read(deviceNameProvider), port: 8080);
                ref.read(isServerRunningProvider.notifier).state = true;
              },
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('启动'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Greeting card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF7C5CFC), Color(0xFF00CEC9)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: const Color(0xFF7C5CFC).withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('下午好 ☀️', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 4),
                const Text('有什么我能帮你的？', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                Row(children: [
                  _StatPill(icon: Icons.memory_rounded, label: '${memoryStats.values.fold(0, (a, b) => a + b)} 记忆'),
                  const SizedBox(width: 8),
                  _StatPill(icon: Icons.auto_awesome_rounded, label: 'DeepSeek V3'),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Quick actions
          Text('快捷操作', style: theme.textTheme.titleSmall?.copyWith(color: const Color(0xFF7C5CFC), fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _ActionCard(icon: Icons.chat_rounded, title: 'AI 对话', subtitle: '开始聊天', onTap: () => context.go('/'))),
            const SizedBox(width: 10),
            Expanded(child: _ActionCard(icon: Icons.swap_horiz_rounded, title: '发送文件', subtitle: '传输到设备', onTap: () => context.go('/devices'))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _ActionCard(icon: Icons.qr_code_rounded, title: '扫码配对', subtitle: '绑定新设备', onTap: () => context.push('/qr-scan'))),
            const SizedBox(width: 10),
            Expanded(child: _ActionCard(icon: Icons.settings_rounded, title: '配置 AI', subtitle: 'API Key & 模型', onTap: () => context.go('/settings'))),
          ]),
          const SizedBox(height: 24),

          // Device mesh
          Text('设备网格', style: theme.textTheme.titleSmall?.copyWith(color: const Color(0xFF7C5CFC), fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          meshDevices.when(
            data: (devices) => devices.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
                    child: const Center(child: Text('未发现其他设备\n点击右上角启动服务', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8B8A9A)))),
                  )
                : Column(children: devices.map((d) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      Container(width: 40, height: 40, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: const Color(0xFF7C5CFC).withValues(alpha: 0.12)), child: const Icon(Icons.devices_rounded, color: Color(0xFF7C5CFC))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d.deviceName, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                        Text(d.capabilities.map((c) => _capLabel(c)).join(' · '), style: theme.textTheme.bodySmall),
                      ])),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: const Text('在线', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600))),
                    ]),
                  )).toList()),
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
            error: (e,_) => Text('${e}'),
          ),
        ],
      ),
    );
  }

  String _capLabel(String cap) {
    switch (cap) {
      case 'ai_chat': return 'AI 对话';
      case 'file_transfer': return '文件传输';
      case 'sms': return '短信';
      case 'notification': return '通知';
      case 'mqtt': return 'IoT';
      case 'shell_exec': return '命令行';
      default: return cap;
    }
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon; final String label;
  const _StatPill({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: Colors.white),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
    ]),
  );
}

class _ActionCard extends StatelessWidget {
  final IconData icon; final String title, subtitle; final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: const Color(0xFF7C5CFC), size: 24),
            const SizedBox(height: 10),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(subtitle, style: theme.textTheme.bodySmall),
          ]),
        ),
      ),
    );
  }
}
