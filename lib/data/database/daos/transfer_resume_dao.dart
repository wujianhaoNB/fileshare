import 'package:drift/drift.dart';
import '../app_database.dart';

class TransferResumeDao extends DatabaseAccessor<AppDatabase> {
  TransferResumeDao(super.db);

  /// Get resume info for a transfer.
  Future<TransferResumeData?> getByTransferId(String transferId) {
    return (select(db.transferResume)
          ..where((t) => t.transferId.equals(transferId)))
        .getSingleOrNull();
  }

  /// Insert resume tracking for a new transfer.
  Future<void> insert(String transferId, String tempFilePath) async {
    await into(db.transferResume).insert(
      TransferResumeCompanion(
        transferId: Value(transferId),
        resumeOffset: const Value(0),
        tempFilePath: Value(tempFilePath),
        lastUpdatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Update the resume offset.
  Future<void> updateOffset(String transferId, int offset) async {
    await (update(db.transferResume)
          ..where((t) => t.transferId.equals(transferId)))
        .write(TransferResumeCompanion(
          resumeOffset: Value(offset),
          lastUpdatedAt: Value(DateTime.now()),
        ));
  }

  /// Update the chunk ACK map (sparse resume data).
  Future<void> updateChunkAckMap(String transferId, String ackMapJson) async {
    await (update(db.transferResume)
          ..where((t) => t.transferId.equals(transferId)))
        .write(TransferResumeCompanion(
          chunkAckMap: Value(ackMapJson),
          lastUpdatedAt: Value(DateTime.now()),
        ));
  }

  /// Delete resume data for a completed/cancelled transfer.
  Future<void> remove(String transferId) async {
    await (delete(db.transferResume)
          ..where((t) => t.transferId.equals(transferId)))
        .go();
  }
}
