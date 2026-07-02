import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/network_utils.dart';
import '../../providers/settings_providers.dart';
import '../../providers/service_providers.dart';
import '../../providers/ai_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final _apiKeyCtrl = TextEditingController();
  late final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _apiKeyCtrl.text = ref.read(apiKeyProvider);
    _nameCtrl.text = ref.read(deviceNameProvider);
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isServerRunning = ref.watch(isServerRunningProvider);
    final bluetoothEnabled = ref.watch(bluetoothEnabledProvider);
    final model = ref.watch(selectedModelProvider);
    final models = ref.watch(availableModelsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置'), actions: [
        TextButton(onPressed: () => context.go('/'), child: const Text('完成')),
      ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          _Section('AI 模型'),
          // API Key
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
            child: TextField(
              controller: _apiKeyCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'DeepSeek API Key',
                hintText: 'sk-...',
                prefixIcon: const Icon(Icons.key_rounded),
                suffixIcon: IconButton(icon: const Icon(Icons.paste_rounded, size: 18), onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null) { _apiKeyCtrl.text = data!.text!; ref.read(apiKeyProvider.notifier).state = data.text!; }
                }),
                border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (v) => ref.read(apiKeyProvider.notifier).state = v,
            ),
          ),
          // Model selector
          Container(
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: models.map((m) => RadioListTile<String>(
                title: Text(m.name, style: theme.textTheme.bodyLarge),
                subtitle: Text(m.provider == 'ollama' ? '本地 Ollama' : '云端 API', style: theme.textTheme.bodySmall),
                secondary: Icon(m.provider == 'ollama' ? Icons.computer_rounded : Icons.cloud_rounded),
                value: m.id, groupValue: model.id,
                onChanged: (v) { if (v != null) { final s = models.firstWhere((x) => x.id == v); ref.read(selectedModelProvider.notifier).state = s; } },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              )).toList(),
            ),
          ),
          const SizedBox(height: 28),

          _Section('设备名称'),
          Container(
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
            child: TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(hintText: '我的设备', prefixIcon: Icon(Icons.phone_android_rounded), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
              onChanged: (v) => ref.read(deviceNameProvider.notifier).state = v,
            ),
          ),
          const SizedBox(height: 28),

          _Section('网络与发现'),
          Container(
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                _ToggleTile(icon: Icons.wifi_rounded, title: '服务状态', subtitle: isServerRunning ? '运行中' : '已停止', value: isServerRunning, onChanged: (v) async {
                  if (v) {
                    final ds = ref.read(discoveryServiceProvider);
                    final sm = ref.read(serverManagerProvider);
                    final fm = ref.read(fileManagerProvider);
                    await fm.init();
                    await sm.start(deviceName: ref.read(deviceNameProvider), hasBluetooth: ref.read(bluetoothEnabledProvider));
                    await ds.start(deviceName: ref.read(deviceNameProvider), port: ref.read(controlPortProvider));
                    ref.read(isServerRunningProvider.notifier).state = true;
                  } else {
                    await ref.read(discoveryServiceProvider).stop();
                    ref.read(isServerRunningProvider.notifier).state = false;
                  }
                }),
                const _Divider(),
                _ToggleTile(icon: Icons.bluetooth_rounded, title: '蓝牙', subtitle: 'Wi-Fi 不可用时使用蓝牙', value: bluetoothEnabled, onChanged: (v) => ref.read(bluetoothEnabledProvider.notifier).state = v),
              ],
            ),
          ),
          const SizedBox(height: 28),

          _Section('设备配对'),
          Container(
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                _NavTile(icon: Icons.qr_code_rounded, title: '展示我的二维码', subtitle: '其他设备扫描后配对', onTap: () => context.push('/qr-display')),
                const _Divider(),
                _NavTile(icon: Icons.qr_code_scanner_rounded, title: '扫描二维码', subtitle: '配对另一台设备', onTap: () => context.push('/qr-scan')),
              ],
            ),
          ),
          const SizedBox(height: 28),

          _Section('数据管理'),
          Container(
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                _NavTile(icon: Icons.delete_sweep_rounded, title: '清除传输历史', subtitle: '删除所有文件传输记录', onTap: () async {
                  final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('确认'), content: const Text('删除所有传输历史？此操作不可撤销。'), actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
                    FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('清除')),
                  ]));
                  if (ok == true) { await ref.read(transferRepositoryProvider).clearHistory(); }
                }),
                const _Divider(),
                _NavTile(icon: Icons.memory_rounded, title: '清除 AI 记忆', subtitle: '删除所有 AI 对话和记忆', onTap: () async {
                  final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('确认'), content: const Text('删除所有对话和 AI 记忆？'), actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
                    FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('清除')),
                  ]));
                  if (ok == true) { ref.read(chatRepositoryProvider).close(); }
                }),
              ],
            ),
          ),
          const SizedBox(height: 28),

          _Section('关于'),
          Container(
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                const _InfoTile(icon: Icons.info_rounded, title: 'AI 助理', subtitle: 'Version 2.0.0 — Phase 0+'),
                const _Divider(),
                _InfoTile(icon: Icons.dns_rounded, title: '主机名', subtitle: NetworkUtils.hostname),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: const Color(0xFF7C5CFC), fontWeight: FontWeight.w700, letterSpacing: 0.3)),
  );
}

class _ToggleTile extends StatelessWidget {
  final IconData icon; final String title, subtitle; final bool value; final ValueChanged<bool> onChanged;
  const _ToggleTile({required this.icon, required this.title, required this.subtitle, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => SwitchListTile(secondary: Icon(icon), title: Text(title, style: Theme.of(context).textTheme.bodyLarge), subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall), value: value, onChanged: onChanged, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)));
}

class _NavTile extends StatelessWidget {
  final IconData icon; final String title, subtitle; final VoidCallback onTap;
  const _NavTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(leading: Icon(icon), title: Text(title, style: Theme.of(context).textTheme.bodyLarge), subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall), trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF8B8A9A)), onTap: onTap, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)));
}

class _InfoTile extends StatelessWidget {
  final IconData icon; final String title, subtitle;
  const _InfoTile({required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => ListTile(leading: Icon(icon), title: Text(title, style: Theme.of(context).textTheme.bodyLarge), subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)));
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Divider(height: 1, indent: 56, color: Theme.of(context).dividerColor.withValues(alpha: 0.5));
}
