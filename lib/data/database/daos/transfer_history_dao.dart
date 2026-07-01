import 'package:drift/drift.dart';
import '../app_database.dart';

class TransferHistoryDao extends DatabaseAccessor<AppDatabase> {
  TransferHistoryDao(super.db);

  /// Get all transfers, ordered by start time descending.
  Future<List<TransferHistoryData>> getAll({int limit = 50, int offset = 0}) {
    return (select(db.transferHistory)
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
          ..limit(limit, offset: offset))
        .get();
  }

  /// Get transfers by direction.
  Future<List<TransferHistoryData>> getByDirection(int direction) {
    return (select(db.transferHistory)
          ..where((t) => t.direction.equals(direction))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .get();
  }

  /// Get transfers by status.
  Future<List<TransferHistoryData>> getByStatus(int status) {
    return (select(db.transferHistory)
          ..where((t) => t.status.equals(status))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .get();
  }

  /// Get active transfers (pending + in_progress + paused).
  Future<List<TransferHistoryData>> getActive() {
    return (select(db.transferHistory)
          ..where((t) => t.status.isSmallerThanValue(2) | t.status.equals(3)))
        .get();
  }

  /// Get transfers for a specific peer.
  Future<List<TransferHistoryData>> getByPeer(String peerId) {
    return (select(db.transferHistory)
          ..where((t) => t.peerId.equals(peerId))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .get();
  }

  /// Insert a new transfer record.
  Future<void> insert(TransferHistoryCompanion entry) async {
    await into(db.transferHistory).insert(entry);
  }

  /// Update transfer progress.
  Future<void> updateProgress(String id, int bytesTransferred) async {
    await (update(db.transferHistory)
          ..where((t) => t.id.equals(id)))
        .write(TransferHistoryCompanion(
          bytesTransferred: Value(bytesTransferred),
        ));
  }

  /// Mark a transfer as completed.
  Future<void> markCompleted(String id) async {
    await (update(db.transferHistory)
          ..where((t) => t.id.equals(id)))
        .write(TransferHistoryCompanion(
          status: const Value(2),
          completedAt: Value(DateTime.now()),
        ));
  }

  /// Mark a transfer as failed.
  Future<void> markFailed(String id, String error) async {
    await (update(db.transferHistory)
          ..where((t) => t.id.equals(id)))
        .write(TransferHistoryCompanion(
          status: const Value(4),
          completedAt: Value(DateTime.now()),
          errorMessage: Value(error),
        ));
  }

  /// Mark a transfer as cancelled.
  Future<void> markCancelled(String id) async {
    await (update(db.transferHistory)
          ..where((t) => t.id.equals(id)))
        .write(TransferHistoryCompanion(
          status: const Value(5),
          completedAt: Value(DateTime.now()),
        ));
  }

  /// Mark a transfer as paused.
  Future<void> markPaused(String id, int bytesTransferred) async {
    await (update(db.transferHistory)
          ..where((t) => t.id.equals(id)))
        .write(TransferHistoryCompanion(
          status: const Value(3),
          bytesTransferred: Value(bytesTransferred),
        ));
  }

  /// Delete a transfer record.
  Future<void> remove(String id) async {
    await (delete(db.transferHistory)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  /// Clear all history.
  Future<void> clearAll() async {
    await delete(db.transferHistory).go();
  }

  /// Watch all transfers as a stream.
  Stream<List<TransferHistoryData>> watchAll() {
    return (select(db.transferHistory)
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .watch();
  }

  /// Watch active transfers.
  Stream<List<TransferHistoryData>> watchActive() {
    return (select(db.transferHistory)
          ..where((t) => t.status.isSmallerThanValue(2) | t.status.equals(3))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .watch();
  }
}
