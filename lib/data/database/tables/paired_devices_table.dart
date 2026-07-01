import 'package:drift/drift.dart';

class PairedDevices extends Table {
  TextColumn get id => text()();
  TextColumn get publicKey => text()(); // base64url-encoded Ed25519 public key
  TextColumn get displayName => text()();
  TextColumn get lastKnownIp => text().nullable()();
  IntColumn get lastKnownPort => integer().withDefault(const Constant(8080))();
  DateTimeColumn get firstPairedAt => dateTime()();
  DateTimeColumn get lastSeenAt => dateTime()();
  IntColumn get trustLevel => integer().withDefault(const Constant(1))(); // 0=untrusted, 1=paired, 2=verified
  TextColumn get capabilities => text().nullable()(); // JSON
  IntColumn get avatarColor => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
