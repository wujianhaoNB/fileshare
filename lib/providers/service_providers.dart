import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/app_database.dart';
import '../data/repositories/device_repository.dart';
import '../data/repositories/transfer_repository.dart';
import '../services/discovery_service.dart';
import '../services/file_manager.dart';
import '../services/transfer_service.dart';

/// Database singleton provider.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Device repository provider.
final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return DeviceRepository(db);
});

/// Transfer repository provider.
final transferRepositoryProvider = Provider<TransferRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return TransferRepository(db);
});

/// File manager provider.
final fileManagerProvider = Provider<FileManager>((ref) {
  final fm = FileManager();
  ref.onDispose(() async {
    // Cleanup is handled by the service layer
  });
  return fm;
});

/// Discovery service provider.
final discoveryServiceProvider = Provider<DiscoveryService>((ref) {
  final deviceRepo = ref.watch(deviceRepositoryProvider);
  final service = DiscoveryService(deviceRepository: deviceRepo);
  ref.onDispose(() => service.stop());
  return service;
});

/// Transfer service provider.
final transferServiceProvider = Provider<TransferService>((ref) {
  final transferRepo = ref.watch(transferRepositoryProvider);
  final fileManager = ref.watch(fileManagerProvider);
  final service = TransferService(
    repository: transferRepo,
    fileManager: fileManager,
  );
  ref.onDispose(() => service.dispose());
  return service;
});
