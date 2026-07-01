import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_strings.dart';
import '../../data/models/device.dart';
import '../../providers/device_providers.dart';
import '../../providers/service_providers.dart';
import '../../providers/settings_providers.dart';
import '../widgets/device_tile.dart';
import '../widgets/empty_state.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _started = false;

  Future<void> _startDiscovery() async {
    if (_started) return;
    _started = true;
    ref.read(isSearchingProvider.notifier).state = true;
    try {
      final discoveryService = ref.read(discoveryServiceProvider);
      final deviceName = ref.read(deviceNameProvider);
      final controlPort = ref.read(controlPortProvider);
      final hasBluetooth = ref.read(bluetoothEnabledProvider);
      await discoveryService.start(
        deviceName: deviceName,
        port: controlPort,
        hasBluetooth: hasBluetooth,
      );
      ref.read(isServerRunningProvider.notifier).state = true;
    } catch (e) {
      _started = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('启动失败: $e')),
        );
      }
    } finally {
      ref.read(isSearchingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(discoveredDevicesProvider);
    final isSearching = ref.watch(isSearchingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: AppStrings.scanQR,
            onPressed: () => context.push('/qr-scan'),
          ),
          IconButton(
            icon: isSearching
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: AppStrings.refreshDevices,
            onPressed: _startDiscovery,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _startDiscovery(),
        child: devicesAsync.when(
          data: (devices) {
            if (devices.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 80),
                EmptyState(
                  icon: Icons.devices_other,
                  title: AppStrings.noDevicesFound,
                  subtitle: '请确保其他设备在同一 Wi-Fi 网络\n且已打开文件快传',
                  action: FilledButton.icon(
                    onPressed: _startDiscovery,
                    icon: const Icon(Icons.search),
                    label: const Text(AppStrings.refreshDevices),
                  ),
                ),
              ]);
            }
            final onlineDevices = devices.where((d) => d.isOnline).toList();
            final pairedDevices = devices.where((d) => d.isPaired).toList();
            return ListView(children: [
              if (onlineDevices.isNotEmpty) ...[
                _SectionHeader(title: AppStrings.onlineDevices, count: onlineDevices.length),
                ...onlineDevices.map((device) => DeviceListTile(
                  device: device,
                  onTap: () => _onSendToDevice(device),
                  onSend: () => _onSendToDevice(device),
                )),
              ],
              if (pairedDevices.isNotEmpty) ...[
                _SectionHeader(title: AppStrings.pairedDevices, count: pairedDevices.length),
                ...pairedDevices.map((device) => DeviceListTile(
                  device: device,
                  onTap: () => _onSendToDevice(device),
                  onSend: () => _onSendToDevice(device),
                )),
              ],
              const SizedBox(height: 80),
            ]);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: EmptyState(
              icon: Icons.error_outline,
              title: '发现错误',
              subtitle: error.toString(),
              action: FilledButton(
                onPressed: () => ref.invalidate(discoveredDevicesProvider),
                child: const Text('重试'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onSendToDevice(Device device) {
    ref.read(selectedDeviceProvider.notifier).state = device;
    context.push('/send', extra: {
      'name': device.displayName,
      'ip': device.ip,
      'port': device.port,
      'id': device.id,
    });
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        )),
        const SizedBox(width: 8),
        Text('$count', style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}
