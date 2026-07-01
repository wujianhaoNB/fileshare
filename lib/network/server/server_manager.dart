import 'dart:async';
import '../../core/constants/app_constants.dart';
import '../../core/logger/app_logger.dart';
import '../protocol/message.dart';
import 'http_control_server.dart';
import 'tcp_data_server.dart';

/// Manages the lifecycle and coordination of HTTP + TCP servers.
class ServerManager {
  final AppLogger _logger = AppLogger();
  final HttpControlServer _httpServer;
  final TcpDataServer _tcpServer;

  String _deviceName = 'FileShare Device';

  ServerManager({
    int httpPort = 8080,
    int tcpPort = 9876,
    required String tempDir,
  })  : _httpServer = HttpControlServer(port: httpPort),
        _tcpServer = TcpDataServer(port: tcpPort, tempDir: tempDir);

  /// Callbacks forwarded from the servers.
  void Function(TransferRequest request)? onTransferRequested;
  void Function(MetadataMessage metadata)? onMetadataReceived;
  void Function(ChunkMessage chunk, int totalReceived)? onChunkReceived;
  void Function()? onTransferComplete;
  void Function(String error)? onTransferError;

  bool get isRunning => _httpServer.isRunning && _tcpServer.isRunning;

  /// Start both servers.
  Future<void> start({
    required String deviceName,
    bool hasBluetooth = false,
  }) async {
    _deviceName = deviceName;

    _httpServer.updateInfo(
      deviceName: deviceName,
      dataPort: AppConstants.defaultDataPort,
      hasBluetooth: hasBluetooth,
    );

    // Wire up callbacks
    _httpServer.onTransferRequested = (request) {
      onTransferRequested?.call(request);
    };

    _tcpServer.onMetadataReceived = (metadata) {
      onMetadataReceived?.call(metadata);
    };

    _tcpServer.onChunkReceived = (chunk, total) {
      onChunkReceived?.call(chunk, total);
    };

    _tcpServer.onTransferComplete = () {
      onTransferComplete?.call();
    };

    _tcpServer.onTransferError = (error) {
      onTransferError?.call(error);
    };

    // Start both servers in parallel
    await Future.wait([
      _httpServer.start(),
      _tcpServer.start(),
    ]);

    _logger.info('Server manager started: HTTP=${AppConstants.defaultControlPort}, TCP=${AppConstants.defaultDataPort}');
  }

  /// Start only the data server (for outgoing transfers).
  Future<void> startDataServer() async {
    await _tcpServer.start();
  }

  /// Accessor for the HTTP server info update.
  void updateDeviceName(String name) {
    _deviceName = name;
    _httpServer.updateInfo(deviceName: name);
  }

  /// Stop both servers.
  Future<void> stop() async {
    await Future.wait([
      _httpServer.stop(),
      _tcpServer.stop(),
    ]);
    _logger.info('Server manager stopped');
  }

  /// Get this device's info for sharing.
  DeviceInfo get deviceInfo => DeviceInfo(
        deviceName: _deviceName,
        dataPort: AppConstants.defaultDataPort,
      );
}
