import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import '../../core/logger/app_logger.dart';
import '../protocol/frame.dart';
import '../protocol/message.dart';
import '../protocol/serializer.dart';

/// Handles the TCP data channel for receiving file transfers.
/// Manages incoming connections, decodes frames, and writes file data to disk.
class TcpDataServer {
  final AppLogger _logger = AppLogger();
  final int _port;
  final String _tempDir;
  ServerSocket? _serverSocket;
  Socket? _clientSocket;
  final FrameReader _frameReader = FrameReader();

  /// Callbacks for transfer events.
  void Function(MetadataMessage metadata)? onMetadataReceived;
  void Function(ChunkMessage chunk, int totalReceived)? onChunkReceived;
  void Function()? onTransferComplete;
  void Function(String error)? onTransferError;
  void Function()? onConnectionLost;

  TcpDataServer({
    int port = 9876,
    required String tempDir,
  })  : _port = port,
        _tempDir = tempDir;

  bool get isRunning => _serverSocket != null;

  /// Start listening for incoming data connections.
  Future<void> start() async {
    if (_serverSocket != null) return;

    try {
      _serverSocket = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        _port,
        backlog: 5,
      );
      _logger.info('TCP data server listening on port $_port');

      _serverSocket!.listen(_handleClient);
    } catch (e) {
      _logger.error('Failed to start TCP data server', e);
      rethrow;
    }
  }

  void _handleClient(Socket client) {
    _clientSocket = client;
    _logger.info('Data channel connected: ${client.remoteAddress.address}');

    RandomAccessFile? file;
    int totalReceived = 0;
    MetadataMessage? metadata;

    client.listen(
      (Uint8List data) {
        final frames = _frameReader.feed(data);

        for (final frame in frames) {
          final message = Serializer.fromFrame(frame);

          if (message is MetadataMessage) {
            metadata = message;
            // Create temp file for receiving
            file = File('$_tempDir/${message.fileName}.part').openSync(
              mode: FileMode.write,
            );
            onMetadataReceived?.call(message);
            _logger.info('Receiving file: ${message.fileName} (${message.fileSize} bytes)');
          } else if (message is ChunkMessage && file != null) {
            // Write chunk to disk at the correct offset
            file!.setPositionSync(message.offset);
            file!.writeFromSync(message.data);
            totalReceived += message.data.length;
            onChunkReceived?.call(message, totalReceived);
          } else if (message is DoneMessage && metadata != null) {
            // Transfer complete
            file?.closeSync();
            final tempPath = '$_tempDir/${metadata!.fileName}.part';
            final finalPath = '$_tempDir/${metadata!.fileName}';
            File(tempPath).renameSync(finalPath);
            onTransferComplete?.call();
            _logger.info('File received complete: ${metadata!.fileName}');
          } else if (message is CancelMessage) {
            file?.closeSync();
            onTransferError?.call(message.reason ?? 'Transfer cancelled');
            _logger.info('Transfer cancelled: ${message.reason}');
          } else if (message is ErrorMessage) {
            file?.closeSync();
            onTransferError?.call(message.error);
            _logger.error('Transfer error from peer: ${message.error}');
          }
        }
      },
      onError: (Object error) {
        _logger.error('Data channel error', error);
        file?.closeSync();
        onConnectionLost?.call();
      },
      onDone: () {
        _logger.info('Data channel closed');
        file?.closeSync();
        _clientSocket = null;
      },
      cancelOnError: false,
    );
  }

  /// Accept an incoming transfer request (send acceptance to the peer).
  Future<void> acceptTransfer() async {
    if (_clientSocket == null) return;
    // For MVP, we don't need to send an explicit acceptance
    // The peer will start sending data after the HTTP /transfer response
    _logger.info('Transfer accepted');
  }

  /// Reject an incoming transfer.
  Future<void> rejectTransfer(String reason) async {
    if (_clientSocket == null) return;
    final frame = Serializer.toFrame(CancelMessage(reason: reason));
    _clientSocket!.add(frame.encode());
    await _clientSocket!.flush();
    _logger.info('Transfer rejected: $reason');
  }

  /// Stop the TCP data server.
  Future<void> stop() async {
    await _clientSocket?.close();
    await _serverSocket?.close();
    _clientSocket = null;
    _serverSocket = null;
    _logger.info('TCP data server stopped');
  }
}
