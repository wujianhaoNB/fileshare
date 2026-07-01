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

/// Main screen showing discovered and paired devices.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Start discovery on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDiscovery();
    });
  }

  Future<void> _startDiscovery() async {
    final discoveryService = ref.read(discoveryServiceProvider);
    final deviceName = ref.read(deviceNameProvider);
    final controlPort = ref.read(controlPortProvider);
    final hasBluetooth = ref.read(bluetoothEnabledProvider);

    try {
      await discoveryService.start(
        deviceName: deviceName,
        port: controlPort,
        hasBluetooth: hasBluetooth,
      );
      ref.read(isServerRunningProvider.notifier).state = true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('启动发现失败: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
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
            onPressed: () {
              context.push('/qr-scan');
            },
          ),
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: isSearching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, key: ValueKey('refresh')),
            ),
            tooltip: AppStrings.refreshDevices,
            onPressed: () async {
              ref.read(isSearchingProvider.notifier).state = true;
              final discoveryService = ref.read(discoveryServiceProvider);
              await discoveryService.refresh();
              ref.read(isSearchingProvider.notifier).state = false;
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(isSearchingProvider.notifier).state = true;
          final discoveryService = ref.read(discoveryServiceProvider);
          await discoveryService.refresh();
          ref.read(isSearchingProvider.notifier).state = false;
        },
        child: devicesAsync.when(
          data: (devices) {
            if (devices.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  EmptyState(
                    icon: Icons.devices_other,
                    title: AppStrings.noDevicesFound,
                    subtitle: '请确保其他设备在同一 Wi-Fi 网络\n且已打开文件快传',
                    action: FilledButton.icon(
                      onPressed: () async {
                        ref.read(isSearchingProvider.notifier).state = true;
                        final discoveryService = ref.read(discoveryServiceProvider);
                        await discoveryService.refresh();
                        ref.read(isSearchingProvider.notifier).state = false;
                      },
                      icon: const Icon(Icons.search),
                      label: const Text(AppStrings.refreshDevices),
                    ),
                  ),
                ],
              );
            }

            final onlineDevices = devices.where((d) => d.isOnline).toList();
            final pairedDevices = devices.where((d) => d.isPaired).toList();

            return ListView(
              children: [
                if (onlineDevices.isNotEmpty) ...[
                  _SectionHeader(title: AppStrings.onlineDevices, count: onlineDevices.length),
                  ...onlineDevices.map((device) => DeviceListTile(
                    device: device,
                    onTap: () => _onDeviceTap(device),
                    onSend: () => _onSendToDevice(device),
                  )),
                ],
                if (pairedDevices.isNotEmpty) ...[
                  _SectionHeader(title: AppStrings.pairedDevices, count: pairedDevices.length),
                  ...pairedDevices.map((device) => DeviceListTile(
                    device: device,
                    onTap: () => _onDeviceTap(device),
                    onSend: () => _onSendToDevice(device),
                  )),
                ],
                if (onlineDevices.isEmpty && pairedDevices.isEmpty)
                  const EmptyState(
                    icon: Icons.devices_other,
                    title: AppStrings.noDevicesFound,
                    subtitle: '请确保其他设备在同一 Wi-Fi 网络。',
                  ),
                const SizedBox(height: 80),
              ],
            );
          },
          loading: () => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(AppStrings.searchingDevices),
              ],
            ),
          ),
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

  void _onDeviceTap(Device device) {
    _onSendToDevice(device);
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
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
