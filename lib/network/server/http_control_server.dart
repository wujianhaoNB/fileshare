import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../core/logger/app_logger.dart';

/// REST API response for device discovery.
class DeviceInfo {
  final String deviceName;
  final String appVersion;
  final bool hasBluetooth;
  final int dataPort;

  const DeviceInfo({
    required this.deviceName,
    this.appVersion = '1.0',
    this.hasBluetooth = false,
    this.dataPort = 9876,
  });

  Map<String, dynamic> toJson() => {
        'device_name': deviceName,
        'app_version': appVersion,
        'has_bluetooth': hasBluetooth,
        'data_port': dataPort,
      };
}

/// Lightweight HTTP server for device discovery and transfer control.
class HttpControlServer {
  final AppLogger _logger = AppLogger();
  HttpServer? _server;
  final int _port;
  String _deviceName = 'FileShare Device';
  int _dataPort = 9876;
  bool _hasBluetooth = false;

  /// Callback when a transfer is requested by a peer.
  void Function(TransferRequest request)? onTransferRequested;

  HttpControlServer({int port = 8080}) : _port = port;

  bool get isRunning => _server != null;

  /// Update server metadata.
  void updateInfo({
    required String deviceName,
    int dataPort = 9876,
    bool hasBluetooth = false,
  }) {
    _deviceName = deviceName;
    _dataPort = dataPort;
    _hasBluetooth = hasBluetooth;
  }

  /// Start the HTTP control server.
  Future<void> start() async {
    if (_server != null) return;

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      _logger.info('HTTP control server listening on port $_port');

      await for (final request in _server!) {
        _handleRequest(request);
      }
    } catch (e) {
      _logger.error('Failed to start HTTP control server', e);
      rethrow;
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      switch (request.uri.path) {
        case '/discover':
          await _handleDiscover(request);
        case '/transfer':
          await _handleTransfer(request);
        case '/status':
          await _handleStatus(request);
        case '/cancel':
          await _handleCancel(request);
        case '/ping':
          await _handlePing(request);
        default:
          await _sendJson(request.response, 404, {'error': 'Not found'});
      }
    } catch (e) {
      _logger.error('Error handling request: ${request.uri.path}', e);
      try {
        await _sendJson(request.response, 500, {'error': 'Internal error'});
      } catch (_) {}
    }
  }

  /// GET /discover - return device info.
  Future<void> _handleDiscover(HttpRequest request) async {
    final info = DeviceInfo(
      deviceName: _deviceName,
      hasBluetooth: _hasBluetooth,
      dataPort: _dataPort,
    );
    await _sendJson(request.response, 200, info.toJson());
  }

  /// POST /transfer - initiate a file transfer to this device.
  Future<void> _handleTransfer(HttpRequest request) async {
    if (request.method != 'POST') {
      await _sendJson(request.response, 405, {'error': 'Method not allowed'});
      return;
    }

    final body = await utf8.decodeStream(request);
    final json = jsonDecode(body) as Map<String, dynamic>;

    final transferRequest = TransferRequest(
      fileName: json['file_name'] as String,
      fileSize: json['file_size'] as int,
      mimeType: json['mime_type'] as String? ?? 'application/octet-stream',
      fileHash: json['file_hash'] as String?,
      senderAddress: request.connectionInfo?.remoteAddress.address ?? 'unknown',
    );

    if (onTransferRequested != null) {
      onTransferRequested!(transferRequest);
      await _sendJson(request.response, 200, {
        'accepted': true,
        'data_port': _dataPort,
        'message': 'Transfer accepted',
      });
    } else {
      await _sendJson(request.response, 503, {
        'accepted': false,
        'message': 'Not accepting transfers',
      });
    }
  }

  /// GET /status/:id - get transfer status.
  Future<void> _handleStatus(HttpRequest request) async {
    await _sendJson(request.response, 200, {
      'status': 'not_implemented',
    });
  }

  /// POST /cancel/:id - cancel a transfer.
  Future<void> _handleCancel(HttpRequest request) async {
    await _sendJson(request.response, 200, {
      'cancelled': true,
    });
  }

  /// GET /ping - health check.
  Future<void> _handlePing(HttpRequest request) async {
    await _sendJson(request.response, 200, {'pong': true});
  }

  Future<void> _sendJson(HttpResponse response, int statusCode, Map<String, dynamic> data) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.headers.add('Access-Control-Allow-Origin', '*');
    response.write(jsonEncode(data));
    await response.close();
  }

  /// Stop the HTTP server.
  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      _logger.info('HTTP control server stopped');
    }
  }
}

/// Incoming transfer request metadata from a peer.
class TransferRequest {
  final String fileName;
  final int fileSize;
  final String mimeType;
  final String? fileHash;
  final String senderAddress;

  TransferRequest({
    required this.fileName,
    required this.fileSize,
    this.mimeType = 'application/octet-stream',
    this.fileHash,
    required this.senderAddress,
  });

  /// Whether the transfer has been accepted.
  bool accepted = false;
}
