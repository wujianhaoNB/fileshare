import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import '../../core/logger/app_logger.dart';
import '../../providers/service_providers.dart';
import '../../services/pairing_service.dart';

/// QR code scanner screen for device pairing.
class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final AppLogger _logger = AppLogger();
  bool _isProcessing = false;
  String _statusText = '将相机对准另一台设备上的二维码';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    _processQrCode(barcode!.rawValue!);
  }

  Future<void> _processQrCode(String jsonStr) async {
    setState(() {
      _isProcessing = true;
      _statusText = '正在验证二维码...';
    });

    try {
      final pairingService = PairingService(
        deviceRepository: ref.read(deviceRepositoryProvider),
      );
      await pairingService.initialize();

      final payload = await pairingService.verifyQrCode(jsonStr);

      if (payload == null) {
        setState(() {
          _isProcessing = false;
          _statusText = '二维码无效或已过期，请重试';
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _statusText = '将相机对准另一台设备上的二维码';
            });
          }
        });
        return;
      }

      // Navigate to confirmation screen
      if (mounted) {
        context.push('/pairing-confirm', extra: {
          'payload': payload,
        });
      }
    } catch (e) {
      _logger.error('QR processing error', e);
      setState(() {
        _isProcessing = false;
        _statusText = '错误: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫描二维码'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Scan overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // Status text
          Positioned(
            bottom: 48,
            left: 32,
            right: 32,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  if (_isProcessing)
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      _statusText,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
