import 'package:drift/drift.dart';

/// Chat conversation records.
class Conversations extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().nullable()();
  TextColumn get modelName => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get messageCount => integer().withDefault(const Constant(0))();
  IntColumn get totalTokens => integer().withDefault(const Constant(0))();
  TextColumn get summary => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Individual messages within a conversation.
class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text().references(Conversations, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => text()(); // 'user', 'assistant', 'system', 'tool'
  TextColumn get content => text()();
  TextColumn get toolCalls => text().nullable()(); // JSON
  TextColumn get toolCallId => text().nullable()();
  IntColumn get tokenCount => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get metadata => text().nullable()(); // JSON

  @override
  Set<Column> get primaryKey => {id};
}
