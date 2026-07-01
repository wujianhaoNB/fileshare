import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/logger/app_logger.dart';
import '../../network/pairing/pairing_handler.dart';
import '../../providers/service_providers.dart';
import '../../services/pairing_service.dart';

/// Screen for confirming a pairing after scanning a QR code.
class PairingConfirmScreen extends ConsumerStatefulWidget {
  final QrPairingPayload payload;

  const PairingConfirmScreen({super.key, required this.payload});

  @override
  ConsumerState<PairingConfirmScreen> createState() => _PairingConfirmScreenState();
}

class _PairingConfirmScreenState extends ConsumerState<PairingConfirmScreen> {
  final AppLogger _logger = AppLogger();
  bool _isPairing = false;
  bool _paired = false;
  String _pairingCode = '';
  String _error = '';

  @override
  void initState() {
    super.initState();
    _computePairingCode();
  }

  void _computePairingCode() {
    try {
      final pairingService = PairingService(
        deviceRepository: ref.read(deviceRepositoryProvider),
      );
      pairingService.initialize();
      _pairingCode = pairingService.generateConfirmationCode(widget.payload.publicKey);
      setState(() {});
    } catch (e) {
      _error = '计算配对码失败';
      _logger.error('Pairing code error', e);
    }
  }

  Future<void> _confirmPairing() async {
    setState(() {
      _isPairing = true;
      _error = '';
    });

    try {
      final pairingService = PairingService(
        deviceRepository: ref.read(deviceRepositoryProvider),
      );
      await pairingService.initialize();
      await pairingService.completePairing(widget.payload);

      setState(() {
        _isPairing = false;
        _paired = true;
      });

      _logger.info('Paired with ${widget.payload.deviceName}');

      // Navigate back after a moment
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          context.go('/');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已与 ${widget.payload.deviceName} 配对 ✓'),
              backgroundColor: Colors.green,
            ),
          );
        }
      });
    } catch (e) {
      _logger.error('Pairing failed', e);
      setState(() {
        _isPairing = false;
        _error = '配对失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('确认配对'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _paired ? _buildSuccess() : _buildConfirm(),
        ),
      ),
    );
  }

  Widget _buildConfirm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Device icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(40),
          ),
          child: Icon(
            Icons.phone_android,
            size: 40,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '与 ${widget.payload.deviceName} 配对？',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'IP: ${widget.payload.ipAddress}:${widget.payload.port}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 32),

        // Pairing confirmation code
        Text(
          '验证码',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          child: Text(
            _pairingCode,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  letterSpacing: 8,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '请确认两台设备上的验证码一致',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 32),

        // Error
        if (_error.isNotEmpty) ...[
          Text(
            _error,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
        ],

        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isPairing ? null : () => context.pop(),
                child: const Text('取消'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton(
                onPressed: _isPairing ? null : _confirmPairing,
                child: _isPairing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('确认配对'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _isPairing ? null : () => context.pop(),
          child: const Text('验证码不一致'),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.check_circle,
          size: 80,
          color: Colors.green,
        ),
        const SizedBox(height: 24),
        Text(
          '配对成功！',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '现在可以安全地与 ${widget.payload.deviceName} 传输文件了',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
