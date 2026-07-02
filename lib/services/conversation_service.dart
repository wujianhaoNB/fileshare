import 'dart:async';
import 'package:uuid/uuid.dart';
import '../core/logger/app_logger.dart';
import '../data/models/conversation.dart';
import '../data/models/chat_message.dart';
import '../data/repositories/chat_repository.dart';

/// Manages chat conversations and message lifecycle.
class ConversationService {
  final AppLogger _logger = AppLogger();
  final ChatRepository _repository;
  final _uuid = const Uuid();

  ConversationService({required ChatRepository repository})
      : _repository = repository;

  /// Create a new conversation.
  Future<Conversation> createConversation({String? title, String modelName = 'deepseek-chat'}) async {
    final now = DateTime.now();
    final conv = Conversation(
      id: _uuid.v4(),
      title: title ?? '新对话',
      modelName: modelName,
      createdAt: now,
      updatedAt: now,
    );
    await _repository.insertConversation(conv);
    return conv;
  }

  /// Add a user message to a conversation.
  Future<ChatMessage> addUserMessage(String conversationId, String content) async {
    final msg = ChatMessage(
      id: _uuid.v4(),
      conversationId: conversationId,
      role: 'user',
      content: content,
      createdAt: DateTime.now(),
    );
    await _repository.insertMessage(msg);

    // Auto-title: use first message as title
    final conv = await _repository.getConversation(conversationId);
    if (conv != null && (conv.title == '新对话' || conv.title == null)) {
      final title = content.length > 30 ? '${content.substring(0, 30)}...' : content;
      await _repository.updateConversation(conv.copyWith(title: title));
    }

    return msg;
  }

  /// Add an assistant message (initially empty, filled by streaming).
  Future<ChatMessage> createAssistantMessage(String conversationId) async {
    final msg = ChatMessage(
      id: _uuid.v4(),
      conversationId: conversationId,
      role: 'assistant',
      content: '',
      createdAt: DateTime.now(),
    );
    await _repository.insertMessage(msg);
    return msg;
  }

  /// Update an assistant message's content (called during streaming).
  Future<void> updateAssistantContent(String messageId, String content) async {
    await _repository.updateMessageContent(messageId, content);
  }

  /// Get the conversation context as API-formatted messages.
  Future<List<Map<String, dynamic>>> buildApiContext(String conversationId, {String? systemPrompt, int maxMessages = 50}) async {
    final messages = <Map<String, dynamic>>[];

    // Add system prompt
    if (systemPrompt != null) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }

    // Add conversation history
    final history = await _repository.getMessages(conversationId, limit: maxMessages);
    for (final msg in history) {
      messages.add(msg.toApiFormat());
    }

    return messages;
  }

  /// Get all conversations.
  Future<List<Conversation>> getConversations() => _repository.getConversations();

  /// Delete a conversation and its messages.
  Future<void> deleteConversation(String id) => _repository.deleteConversation(id);

  /// Get messages for a conversation.
  Future<List<ChatMessage>> getMessages(String conversationId, {int limit = 100, int offset = 0}) =>
      _repository.getMessages(conversationId, limit: limit, offset: offset);

  /// Watch messages for a conversation.
  Stream<List<ChatMessage>> watchMessages(String conversationId) =>
      _repository.watchMessages(conversationId);
}
