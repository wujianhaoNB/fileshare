import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/daos/paired_device_dao.dart';
import '../models/device.dart';

/// Repository for managing paired and discovered devices.
class DeviceRepository {
  final PairedDeviceDao _dao;

  DeviceRepository(AppDatabase db) : _dao = PairedDeviceDao(db);

  /// Get all paired devices.
  Future<List<Device>> getPairedDevices() async {
    final rows = await _dao.getAllPaired();
    return rows.map(_toModel).toList();
  }

  /// Watch paired devices as a stream.
  Stream<List<Device>> watchPairedDevices() {
    return _dao.watchAll().map((rows) => rows.map(_toModel).toList());
  }

  /// Add or update a paired device.
  Future<void> upsertDevice(Device device) async {
    await _dao.upsert(PairedDevicesCompanion(
      id: Value(device.id),
      publicKey: Value(device.publicKey ?? ''),
      displayName: Value(device.displayName),
      lastKnownIp: Value(device.ip),
      lastKnownPort: Value(device.port),
      firstPairedAt: Value(device.lastSeenAt ?? DateTime.now()),
      lastSeenAt: Value(DateTime.now()),
      trustLevel: Value(device.trustLevel),
      capabilities: const Value(null),
    ));
  }

  /// Update the last-seen timestamp and IP of a paired device.
  Future<void> updateLastSeen(String id, String ip, int port) async {
    await _dao.updateLastKnownIp(id, ip, port);
    await _dao.updateLastSeen(id);
  }

  /// Remove a paired device.
  Future<void> removeDevice(String id) async {
    await _dao.remove(id);
  }

  /// Find a paired device by its public key.
  Future<Device?> findByPublicKey(String publicKey) async {
    final row = await _dao.getByPublicKey(publicKey);
    if (row == null) return null;
    return _toModel(row);
  }

  Device _toModel(PairedDevice row) {
    return Device(
      id: row.id,
      displayName: row.displayName,
      publicKey: row.publicKey,
      ip: row.lastKnownIp ?? '',
      port: row.lastKnownPort,
      trustLevel: row.trustLevel,
      lastSeenAt: row.lastSeenAt,
      isOnline: false,
    );
  }
}
