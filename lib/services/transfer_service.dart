import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:uuid/uuid.dart';
import '../core/constants/app_constants.dart';
import '../core/logger/app_logger.dart';
import '../core/extensions/file_extensions.dart';
import '../data/models/transfer_progress.dart';
import '../data/models/transfer_record.dart';
import '../data/repositories/transfer_repository.dart';
import '../network/protocol/message.dart';
import '../network/server/server_manager.dart';
import '../network/transport/tcp_transport.dart';
import 'file_manager.dart';

/// Manages the lifecycle of file transfers (send and receive).
class TransferService {
  final AppLogger _logger = AppLogger();
  final TransferRepository _repository;
  final FileManager _fileManager;
  final ServerManager _serverManager;
  final TcpTransport _transport = TcpTransport();
  final _uuid = const Uuid();

  /// Active transfers by ID.
  final _activeTransfers = <String, TransferProgress>{};

  /// Controller for transfer progress updates.
  final _progressController = StreamController<Map<String, TransferProgress>>.broadcast();

  /// Stream of current transfer states.
  Stream<Map<String, TransferProgress>> get progressStream => _progressController.stream;

  /// Get current transfer progress snapshot.
  Map<String, TransferProgress> get activeTransfers => Map.unmodifiable(_activeTransfers);

  TransferService({
    required TransferRepository repository,
    required FileManager fileManager,
    required ServerManager serverManager,
  })  : _repository = repository,
        _fileManager = fileManager,
        _serverManager = serverManager {
    _wireServerCallbacks();
  }

  /// Wire up ServerManager callbacks for incoming transfers.
  void _wireServerCallbacks() {
    _serverManager.onMetadataReceived = (metadata) {
      // The incoming transfer will be created by handleIncomingFile
      _logger.info('Metadata received: ${metadata.fileName}');
    };

    _serverManager.onChunkReceived = (chunk, totalReceived) {
      _logger.debug('Chunk received: offset=${chunk.offset}, total=$totalReceived');
    };

    _serverManager.onTransferComplete = () {
      _logger.info('Incoming transfer complete');
    };

    _serverManager.onTransferError = (error) {
      _logger.error('Incoming transfer error: $error');
    };
  }

  /// Send a file to a peer device.
  Future<String> sendFile({
    required String filePath,
    required String peerAddress,
    required int peerDataPort,
    required String peerName,
    String? peerId,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File not found: $filePath');
    }

    final fileName = file.path.split(Platform.pathSeparator).last;
    final fileSize = await file.length();
    final mimeType = fileName.mimeType;
    final transferId = _uuid.v4();

    // Create transfer record
    final record = TransferRecord(
      id: transferId,
      peerId: peerId ?? 'unknown',
      direction: TransferDirection.outgoing,
      fileName: fileName,
      fileSize: fileSize,
      mimeType: mimeType,
      status: TransferStatus.inProgress,
      startedAt: DateTime.now(),
    );
    await _repository.createRecord(record);

    // Initialize progress
    _updateProgress(transferId, TransferProgress(
      transferId: transferId,
      fileName: fileName,
      fileSize: fileSize,
      peerName: peerName,
      isIncoming: false,
      state: TransferProgressState.connecting,
    ));

    try {
      // Connect to peer's data channel
      await _transport.connect(peerAddress, peerDataPort);

      _updateProgressState(transferId, TransferProgressState.transferring);

      // Send metadata
      await _transport.sendMessage(MetadataMessage(
        fileName: fileName,
        fileSize: fileSize,
        mimeType: mimeType,
      ));

      // Send file in chunks
      final raf = await file.open(mode: FileMode.read);
      try {
        var offset = 0;
        var bytesSent = 0;
        var lastSpeedUpdate = DateTime.now();
        var bytesSinceLastUpdate = 0;

        while (offset < fileSize) {
          final chunkSize = min(AppConstants.chunkSize, fileSize - offset);
          await raf.setPosition(offset);
          final data = await raf.read(chunkSize);

          await _transport.sendMessage(ChunkMessage(
            offset: offset,
            data: data,
          ));

          offset += chunkSize;
          bytesSent += chunkSize;

          // Update progress
          bytesSinceLastUpdate += chunkSize;
          final now = DateTime.now();
          final elapsed = now.difference(lastSpeedUpdate);

          if (elapsed >= const Duration(milliseconds: 500)) {
            final speed = bytesSinceLastUpdate / elapsed.inMilliseconds * 1000;
            _updateProgress(transferId, TransferProgress(
              transferId: transferId,
              fileName: fileName,
              fileSize: fileSize,
              bytesTransferred: bytesSent,
              speedBytesPerSecond: speed,
              peerName: peerName,
              isIncoming: false,
              state: TransferProgressState.transferring,
            ));
            bytesSinceLastUpdate = 0;
            lastSpeedUpdate = now;
          }

          await _repository.updateProgress(transferId, bytesSent);
        }

        // Send done message
        await _transport.sendMessage(const DoneMessage());
      } finally {
        await raf.close();
      }

      // Mark complete
      await _repository.markCompleted(transferId);
      _updateProgressState(transferId, TransferProgressState.completed);

      _logger.info('File sent complete: $fileName ($fileSize bytes)');
      return transferId;
    } catch (e) {
      _logger.error('Failed to send file: $fileName', e);
      await _repository.markFailed(transferId, e.toString());
      _updateProgressState(transferId, TransferProgressState.failed, error: e.toString());
      rethrow;
    }
  }

  /// Handle an incoming file (called when TcpDataServer receives data).
  Future<String> handleIncomingFile({
    required MetadataMessage metadata,
    required String peerAddress,
    required String peerName,
    String? peerId,
  }) async {
    final transferId = _uuid.v4();

    // Init temp file for resume
    final tempPath = _fileManager.getTempPath(transferId, metadata.fileName);
    await _repository.initResume(transferId, tempPath);

    // Create transfer record
    final record = TransferRecord(
      id: transferId,
      peerId: peerId ?? 'unknown',
      direction: TransferDirection.incoming,
      fileName: metadata.fileName,
      fileSize: metadata.fileSize,
      mimeType: metadata.mimeType,
      status: TransferStatus.inProgress,
      startedAt: DateTime.now(),
    );
    await _repository.createRecord(record);

    _updateProgress(transferId, TransferProgress(
      transferId: transferId,
      fileName: metadata.fileName,
      fileSize: metadata.fileSize,
      peerName: peerName,
      isIncoming: true,
      state: TransferProgressState.transferring,
    ));

    _logger.info('Receiving file: ${metadata.fileName} (${metadata.fileSize} bytes)');
    return transferId;
  }

  /// Update incoming transfer progress.
  void updateIncomingProgress(String transferId, int totalReceived) {
    final existing = _activeTransfers[transferId];
    if (existing == null) return;

    _updateProgress(transferId, existing.copyWith(
      bytesTransferred: totalReceived,
      speedBytesPerSecond: _calculateSpeed(transferId, totalReceived),
    ));

    _repository.updateProgress(transferId, totalReceived);
  }

  /// Complete an incoming transfer.
  Future<void> completeIncoming(String transferId) async {
    final progress = _activeTransfers[transferId];
    if (progress == null) return;

    await _repository.markCompleted(transferId);
    _updateProgressState(transferId, TransferProgressState.completed);
  }

  /// Fail an incoming transfer.
  Future<void> failIncoming(String transferId, String error) async {
    await _repository.markFailed(transferId, error);
    _updateProgressState(transferId, TransferProgressState.failed, error: error);
  }

  /// Cancel a transfer.
  Future<void> cancelTransfer(String transferId) async {
    try {
      await _transport.sendMessage(const CancelMessage(reason: 'Cancelled by user'));
    } catch (_) {}
    await _repository.markCancelled(transferId);
    _updateProgressState(transferId, TransferProgressState.cancelled);
  }

  // --- Internal helpers ---

  final _speedHistory = <String, List<_SpeedSample>>{};

  double _calculateSpeed(String transferId, int bytesTransferred) {
    final now = DateTime.now();
    _speedHistory.putIfAbsent(transferId, () => []);
    final history = _speedHistory[transferId]!;

    history.add(_SpeedSample(now, bytesTransferred));

    // Keep only last 2 seconds of samples
    history.removeWhere((s) => now.difference(s.time).inSeconds > 2);

    if (history.length < 2) return 0;

    final oldest = history.first;
    final elapsed = now.difference(oldest.time).inMilliseconds;
    if (elapsed == 0) return 0;

    return (bytesTransferred - oldest.bytes) / elapsed * 1000;
  }

  void _updateProgress(String transferId, TransferProgress progress) {
    _activeTransfers[transferId] = progress;
    _progressController.add(Map.from(_activeTransfers));
  }

  void _updateProgressState(String transferId, TransferProgressState state, {String? error}) {
    final existing = _activeTransfers[transferId];
    if (existing == null) return;

    _updateProgress(transferId, existing.copyWith(state: state, error: error));

    // Clean up completed/failed/cancelled after a delay
    if (state == TransferProgressState.completed ||
        state == TransferProgressState.failed ||
        state == TransferProgressState.cancelled) {
      Future.delayed(const Duration(seconds: 5), () {
        _activeTransfers.remove(transferId);
        _speedHistory.remove(transferId);
        _progressController.add(Map.from(_activeTransfers));
      });
    }
  }

  /// Dispose resources.
  Future<void> dispose() async {
    await _transport.dispose();
    await _progressController.close();
  }
}

class _SpeedSample {
  final DateTime time;
  final int bytes;
  const _SpeedSample(this.time, this.bytes);
}
