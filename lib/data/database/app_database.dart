import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables/paired_devices_table.dart';
import 'tables/transfer_history_table.dart';
import 'tables/transfer_resume_table.dart';
import 'tables/app_settings_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    PairedDevices,
    TransferHistory,
    TransferResume,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Future migrations go here
        },
        beforeOpen: (OpeningDetails details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await customStatement('PRAGMA journal_mode = WAL');
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'fileshare', 'fileshare.db'));

    // Ensure the directory exists
    await file.parent.create(recursive: true);

    return NativeDatabase.createInBackground(file);
  });
}
