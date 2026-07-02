/// Represents a chat conversation.
class Conversation {
  final String id;
  final String title;
  final String modelName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;
  final int messageCount;
  final int totalTokens;
  final String? summary;

  const Conversation({
    required this.id,
    required this.title,
    required this.modelName,
    required this.createdAt,
    required this.updatedAt,
    this.isArchived = false,
    this.messageCount = 0,
    this.totalTokens = 0,
    this.summary,
  });

  Conversation copyWith({
    String? id,
    String? title,
    String? modelName,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isArchived,
    int? messageCount,
    int? totalTokens,
    String? summary,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      modelName: modelName ?? this.modelName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
      messageCount: messageCount ?? this.messageCount,
      totalTokens: totalTokens ?? this.totalTokens,
      summary: summary ?? this.summary,
    );
  }
}
