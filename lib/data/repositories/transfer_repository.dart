import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/daos/transfer_history_dao.dart';
import '../database/daos/transfer_resume_dao.dart';
import '../models/transfer_record.dart';

/// Repository for managing transfer history and resume state.
class TransferRepository {
  final TransferHistoryDao _historyDao;
  final TransferResumeDao _resumeDao;

  TransferRepository(AppDatabase db)
      : _historyDao = TransferHistoryDao(db),
        _resumeDao = TransferResumeDao(db);

  // --- History ---

  Future<List<TransferRecord>> getHistory({int limit = 50, int offset = 0}) async {
    final rows = await _historyDao.getAll(limit: limit, offset: offset);
    return rows.map(_toRecord).toList();
  }

  Stream<List<TransferRecord>> watchHistory() {
    return _historyDao.watchAll().map((rows) => rows.map(_toRecord).toList());
  }

  Stream<List<TransferRecord>> watchActive() {
    return _historyDao.watchActive().map((rows) => rows.map(_toRecord).toList());
  }

  Future<List<TransferRecord>> getActive() async {
    final rows = await _historyDao.getActive();
    return rows.map(_toRecord).toList();
  }

  Future<String> createRecord(TransferRecord record) async {
    await _historyDao.insert(TransferHistoryCompanion(
      id: Value(record.id),
      peerId: Value(record.peerId),
      direction: Value(record.direction.index),
      fileName: Value(record.fileName),
      fileSize: Value(record.fileSize),
      mimeType: Value(record.mimeType),
      sha256Hash: Value(record.sha256Hash),
      filePath: Value(record.filePath),
      status: Value(record.status.index),
      startedAt: Value(record.startedAt),
      transport: Value(record.transport.name),
    ));
    return record.id;
  }

  Future<void> updateProgress(String id, int bytesTransferred) async {
    await _historyDao.updateProgress(id, bytesTransferred);
  }

  Future<void> markCompleted(String id) async {
    await _historyDao.markCompleted(id);
  }

  Future<void> markFailed(String id, String error) async {
    await _historyDao.markFailed(id, error);
  }

  Future<void> markCancelled(String id) async {
    await _historyDao.markCancelled(id);
  }

  Future<void> markPaused(String id, int bytesTransferred) async {
    await _historyDao.markPaused(id, bytesTransferred);
  }

  Future<void> clearHistory() async {
    await _historyDao.clearAll();
  }

  // --- Resume ---

  Future<void> initResume(String transferId, String tempPath) async {
    await _resumeDao.insert(transferId, tempPath);
  }

  Future<TransferResumeData?> getResumeData(String transferId) async {
    return _resumeDao.getByTransferId(transferId);
  }

  Future<void> updateResumeOffset(String transferId, int offset) async {
    await _resumeDao.updateOffset(transferId, offset);
  }

  Future<void> removeResumeData(String transferId) async {
    await _resumeDao.remove(transferId);
  }

  TransferRecord _toRecord(TransferHistoryData row) {
    return TransferRecord(
      id: row.id,
      peerId: row.peerId,
      direction: TransferDirection.values[row.direction],
      fileName: row.fileName,
      fileSize: row.fileSize,
      mimeType: row.mimeType,
      sha256Hash: row.sha256Hash,
      filePath: row.filePath,
      status: TransferStatus.values[row.status],
      startedAt: row.startedAt,
      completedAt: row.completedAt,
      bytesTransferred: row.bytesTransferred,
      transport: _parseTransport(row.transport),
      errorMessage: row.errorMessage,
    );
  }

  TransferTransport _parseTransport(String t) {
    switch (t) {
      case 'tcp':
        return TransferTransport.tcp;
      case 'bluetooth':
        return TransferTransport.bluetooth;
      case 'relay':
        return TransferTransport.relay;
      default:
        return TransferTransport.tcp;
    }
  }
}
