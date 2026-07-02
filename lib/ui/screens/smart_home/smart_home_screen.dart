import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/smart_home_device.dart';
import '../../../providers/ai_providers.dart';
import '../../../services/smart_home_service.dart';

class SmartHomeScreen extends ConsumerStatefulWidget {
  const SmartHomeScreen({super.key});
  @override
  ConsumerState<SmartHomeScreen> createState() => _SmartHomeScreenState();
}

class _SmartHomeScreenState extends ConsumerState<SmartHomeScreen> {
  String? _haUrl;
  String? _haToken;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showConfig());
  }

  void _showConfig() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ConfigDialog(
        onConnect: (url, token) {
          _haUrl = url; _haToken = token;
          ref.read(smartHomeServiceProvider).configureHomeAssistant(url: url, token: token);
          ref.read(smartHomeServiceProvider).discoverFromHA();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final devicesAsync = ref.watch(smartHomeDevicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('智能家居'),
        actions: [IconButton(icon: const Icon(Icons.add_link_rounded), tooltip: '配置', onPressed: _showConfig)],
      ),
      body: devicesAsync.when(
        data: (devices) => devices.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.home_rounded, size: 64, color: theme.colorScheme.primary.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                Text('未发现智能设备', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('连接 HomeAssistant 或配置 MQTT', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 16),
                FilledButton.icon(onPressed: _showConfig, icon: const Icon(Icons.add_link_rounded), label: const Text('连接 HomeAssistant')),
              ]))
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.1),
                itemCount: devices.length,
                itemBuilder: (_, i) => _DeviceCard(device: devices[i]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e,_) => Center(child: Text('${e}')),
      ),
    );
  }
}

class _DeviceCard extends ConsumerWidget {
  final SmartHomeDevice device;
  const _DeviceCard({required this.device});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isOn = device.isOn;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _toggle(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Icon(_iconForType(), color: isOn ? const Color(0xFF7C5CFC) : theme.colorScheme.onSurface, size: 28),
                Switch(value: isOn, onChanged: (v) => _toggle(context, ref), activeColor: const Color(0xFF7C5CFC)),
              ]),
              const Spacer(),
              Text(device.name, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(_stateLabel(), style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType() {
    switch (device.type) {
      case 'light': return Icons.lightbulb_rounded;
      case 'switch': return Icons.power_rounded;
      case 'climate': return Icons.thermostat_rounded;
      case 'lock': return Icons.lock_rounded;
      case 'cover': return Icons.blinds_rounded;
      case 'media_player': return Icons.speaker_rounded;
      case 'fan': return Icons.air_rounded;
      default: return Icons.devices_rounded;
    }
  }

  String _stateLabel() {
    final s = device.currentState;
    if (device.type == 'climate') return '${device.attributes?['temperature'] ?? '--'}°C';
    if (device.type == 'sensor') return device.attributes?['unit_of_measurement'] != null ? '$s ${device.attributes!['unit_of_measurement']}' : s;
    return s == 'on' ? '已开启' : s == 'off' ? '已关闭' : s;
  }

  void _toggle(BuildContext context, WidgetRef ref) {
    final svc = ref.read(smartHomeServiceProvider);
    svc.controlDevice(device, SmartHomeAction(onOff: !device.isOn));
  }
}

class _ConfigDialog extends StatefulWidget {
  final void Function(String url, String token) onConnect;
  const _ConfigDialog({required this.onConnect});
  @override State<_ConfigDialog> createState() => _ConfigDialogState();
}
class _ConfigDialogState extends State<_ConfigDialog> {
  final _urlCtrl = TextEditingController(text: 'http://192.168.1.100:8123');
  final _tokenCtrl = TextEditingController();
  @override void dispose() { _urlCtrl.dispose(); _tokenCtrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('连接 HomeAssistant'),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: _urlCtrl, decoration: const InputDecoration(labelText: 'HA URL', hintText: 'http://192.168.x.x:8123')),
      const SizedBox(height: 16),
      TextField(controller: _tokenCtrl, decoration: const InputDecoration(labelText: 'Bearer Token', hintText: '长期访问令牌')),
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
      FilledButton(onPressed: () { widget.onConnect(_urlCtrl.text.trim(), _tokenCtrl.text.trim()); Navigator.pop(context); }, child: const Text('连接')),
    ],
  );
}
