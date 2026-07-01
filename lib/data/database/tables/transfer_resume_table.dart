import 'package:drift/drift.dart';

class TransferResume extends Table {
  TextColumn get transferId => text()(); // FK to transfer_history
  IntColumn get resumeOffset => integer()(); // last fully-written byte offset
  TextColumn get tempFilePath => text()(); // path to partial file
  TextColumn get chunkAckMap => text().nullable()(); // compressed bitmap as JSON ranges
  DateTimeColumn get lastUpdatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {transferId};
}
