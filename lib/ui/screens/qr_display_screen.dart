import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/utils/network_utils.dart';
import '../../providers/service_providers.dart';
import '../../providers/settings_providers.dart';
import '../../services/pairing_service.dart';

/// Displays a QR code that other devices can scan to initiate pairing.
class QrDisplayScreen extends ConsumerStatefulWidget {
  const QrDisplayScreen({super.key});

  @override
  ConsumerState<QrDisplayScreen> createState() => _QrDisplayScreenState();
}

class _QrDisplayScreenState extends ConsumerState<QrDisplayScreen> {
  String _qrData = '';
  String _localIp = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generateQr();
  }

  Future<void> _generateQr() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final deviceName = ref.read(deviceNameProvider);
      final port = ref.read(controlPortProvider);
      final ip = await NetworkUtils.getLocalIp() ?? '未知';

      // Generate pairing QR
      final pairingService = PairingService(
        deviceRepository: ref.read(deviceRepositoryProvider),
      );
      await pairingService.initialize();
      final qrJson = await pairingService.generateQrCodeJsonWithIp(
        deviceName: deviceName,
        port: port,
      );

      setState(() {
        _qrData = qrJson;
        _localIp = ip;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的二维码'),
        actions: [
          if (_qrData.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _generateQr,
              tooltip: '重新生成',
            ),
        ],
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : _error != null
                ? _buildError()
                : _buildQr(),
      ),
    );
  }

  Widget _buildQr() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '用另一台设备上的文件快传扫描',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: QrImageView(
                data: _qrData,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '设备：${ref.read(deviceNameProvider)}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'IP：$_localIp',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _generateQr,
            icon: const Icon(Icons.refresh),
            label: const Text('重新生成'),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            '生成二维码失败',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _generateQr,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
