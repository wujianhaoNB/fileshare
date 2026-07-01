import 'package:drift/drift.dart';
import '../app_database.dart';

class PairedDeviceDao extends DatabaseAccessor<AppDatabase> {
  PairedDeviceDao(super.db);

  /// Get all paired devices, ordered by last seen.
  Future<List<PairedDevice>> getAllPaired() {
    return (select(db.pairedDevices)
          ..orderBy([(t) => OrderingTerm.desc(t.lastSeenAt)])
        ).get();
  }

  /// Find a paired device by its public key.
  Future<PairedDevice?> getByPublicKey(String publicKey) {
    return (select(db.pairedDevices)
          ..where((t) => t.publicKey.equals(publicKey)))
        .getSingleOrNull();
  }

  /// Get a paired device by ID.
  Future<PairedDevice?> getById(String id) {
    return (select(db.pairedDevices)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Insert or update a device (upsert by public key).
  Future<void> upsert(PairedDevicesCompanion device) async {
    final existing = await getByPublicKey(device.publicKey.value);
    if (existing != null) {
      await (update(db.pairedDevices)
            ..where((t) => t.id.equals(existing.id)))
          .write(device);
    } else {
      await into(db.pairedDevices).insert(device);
    }
  }

  /// Update last seen timestamp.
  Future<void> updateLastSeen(String id) async {
    await (update(db.pairedDevices)
          ..where((t) => t.id.equals(id)))
        .write(PairedDevicesCompanion(
          lastSeenAt: Value(DateTime.now()),
        ));
  }

  /// Update the last known IP for a device.
  Future<void> updateLastKnownIp(String id, String ip, int port) async {
    await (update(db.pairedDevices)
          ..where((t) => t.id.equals(id)))
        .write(PairedDevicesCompanion(
          lastKnownIp: Value(ip),
          lastKnownPort: Value(port),
        ));
  }

  /// Remove a paired device.
  Future<void> remove(String id) async {
    await (delete(db.pairedDevices)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  /// Watch all paired devices as a stream.
  Stream<List<PairedDevice>> watchAll() {
    return (select(db.pairedDevices)
          ..orderBy([(t) => OrderingTerm.desc(t.lastSeenAt)]))
        .watch();
  }
}
