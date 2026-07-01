import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/transfer_progress.dart';
import '../data/models/transfer_record.dart';
import 'service_providers.dart';

/// Active transfer progress (live).
final activeTransfersProvider = StreamProvider<Map<String, TransferProgress>>((ref) {
  final transferService = ref.watch(transferServiceProvider);
  return transferService.progressStream;
});

/// Transfer history from the repository.
final transferHistoryProvider = StreamProvider<List<TransferRecord>>((ref) {
  final transferRepo = ref.watch(transferRepositoryProvider);
  return transferRepo.watchHistory();
});

/// Active transfers only.
final activeTransfersListProvider = StreamProvider<List<TransferRecord>>((ref) {
  final transferRepo = ref.watch(transferRepositoryProvider);
  return transferRepo.watchActive();
});

/// Currently selected files to send (paths).
final selectedFilesProvider = StateProvider<List<String>>((ref) => []);
