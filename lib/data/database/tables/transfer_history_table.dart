import 'package:drift/drift.dart';

class TransferHistory extends Table {
  TextColumn get id => text()();
  TextColumn get peerId => text()(); // FK to paired_devices
  IntColumn get direction => integer()(); // 0=outgoing, 1=incoming
  TextColumn get fileName => text()();
  IntColumn get fileSize => integer()();
  TextColumn get mimeType => text().nullable()();
  TextColumn get sha256Hash => text().nullable()(); // hex-encoded
  TextColumn get filePath => text().nullable()(); // local path
  IntColumn get status => integer()(); // 0=pending, 1=in_progress, 2=completed, 3=paused, 4=failed, 5=cancelled
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get bytesTransferred => integer().withDefault(const Constant(0))();
  TextColumn get transport => text().withDefault(const Constant('tcp'))(); // 'tcp', 'bluetooth'
  TextColumn get errorMessage => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
