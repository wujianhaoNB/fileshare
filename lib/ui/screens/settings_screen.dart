import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/network_utils.dart';
import '../../providers/settings_providers.dart';
import '../../providers/service_providers.dart';

/// Settings screen for configuring the app.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _controlPortController;
  late final TextEditingController _dataPortController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: ref.read(deviceNameProvider),
    );
    _controlPortController = TextEditingController(
      text: ref.read(controlPortProvider).toString(),
    );
    _dataPortController = TextEditingController(
      text: ref.read(dataPortProvider).toString(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _controlPortController.dispose();
    _dataPortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isServerRunning = ref.watch(isServerRunningProvider);
    final bluetoothEnabled = ref.watch(bluetoothEnabledProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Device Name
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: AppStrings.deviceName,
              hintText: 'Enter your device name',
              prefixIcon: Icon(Icons.phone_android),
            ),
            onChanged: (value) {
              ref.read(deviceNameProvider.notifier).state = value;
            },
          ),
          const SizedBox(height: 24),

          // Network section
          Text(
            'Network',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),

          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Server Status'),
                  subtitle: Text(
                    isServerRunning ? 'Running' : 'Stopped',
                  ),
                  trailing: Switch(
                    value: isServerRunning,
                    onChanged: (value) async {
                      if (value) {
                        final discoveryService = ref.read(discoveryServiceProvider);
                        final deviceName = ref.read(deviceNameProvider);
                        final controlPort = ref.read(controlPortProvider);
                        try {
                          await discoveryService.start(
                            deviceName: deviceName,
                            port: controlPort,
                          );
                          ref.read(isServerRunningProvider.notifier).state = true;
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to start: $e')),
                            );
                          }
                        }
                      } else {
                        final discoveryService = ref.read(discoveryServiceProvider);
                        await discoveryService.stop();
                        ref.read(isServerRunningProvider.notifier).state = false;
                      }
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Control Port'),
                  subtitle: Text('Port: ${ref.watch(controlPortProvider)}'),
                ),
                ListTile(
                  title: const Text('Data Port'),
                  subtitle: Text('Port: ${ref.watch(dataPortProvider)}'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Bluetooth section
          Text(
            'Bluetooth',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),

          Card(
            child: SwitchListTile(
              title: const Text('Enable Bluetooth'),
              subtitle: const Text('Use Bluetooth when Wi-Fi is unavailable'),
              value: bluetoothEnabled,
              onChanged: (value) {
                ref.read(bluetoothEnabledProvider.notifier).state = value;
              },
            ),
          ),

          const SizedBox(height: 24),

          // Pairing section
          Text(
            'Pairing',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.qr_code),
                  title: const Text('Show My QR Code'),
                  subtitle: const Text('Other devices can scan to pair'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    context.push('/qr-display');
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.qr_code_scanner),
                  title: const Text('Scan QR Code'),
                  subtitle: const Text('Pair with another device'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    context.push('/qr-scan');
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Storage section
          Text(
            'Storage',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),

          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Clear Transfer History'),
                  leading: const Icon(Icons.delete_sweep),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog.adaptive(
                        title: const Text('Clear History'),
                        content: const Text(
                          'Delete all transfer history? This cannot be undone.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      final transferRepo = ref.read(transferRepositoryProvider);
                      await transferRepo.clearHistory();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('History cleared')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // About section
          Text(
            'About',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),

          Card(
            child: Column(
              children: [
                const ListTile(
                  title: Text('FileShare'),
                  subtitle: Text('Version 1.0.0 (MVP)'),
                  leading: Icon(Icons.info),
                ),
                ListTile(
                  title: const Text('Hostname'),
                  subtitle: Text(NetworkUtils.hostname),
                  leading: const Icon(Icons.dns),
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
