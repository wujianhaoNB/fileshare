import 'dart:async';
import '../models/conversation.dart';
import '../models/chat_message.dart';

/// In-memory chat repository for Phase 0 MVP.
/// Will be upgraded to full SQLite persistence in Phase 1.
class ChatRepository {

  final _conversations = <String, Conversation>{};
  final _messages = <String, List<ChatMessage>>{};
  final _controllers = <String, StreamController<List<ChatMessage>>>{};

  /// Get or create a stream controller for a conversation.
  StreamController<List<ChatMessage>> _getController(String conversationId) {
    if (!_controllers.containsKey(conversationId)) {
      _controllers[conversationId] = StreamController<List<ChatMessage>>.broadcast();
    }
    return _controllers[conversationId]!;
  }

  void _emit(String conversationId) {
    if (_controllers.containsKey(conversationId)) {
      final msgs = _messages[conversationId] ?? [];
      final sorted = [...msgs]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _controllers[conversationId]!.add(sorted);
    }
  }

  // --- Conversations ---

  Future<List<Conversation>> getConversations({bool includeArchived = false}) async {
    final all = _conversations.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (includeArchived) return all;
    return all.where((c) => !c.isArchived).toList();
  }

  Future<Conversation?> getConversation(String id) async {
    return _conversations[id];
  }

  Future<void> insertConversation(Conversation conv) async {
    _conversations[conv.id] = conv;
    _messages.putIfAbsent(conv.id, () => []);
  }

  Future<void> updateConversation(Conversation conv) async {
    _conversations[conv.id] = conv;
  }

  Future<void> deleteConversation(String id) async {
    _conversations.remove(id);
    _messages.remove(id);
  }

  // --- Messages ---

  Future<List<ChatMessage>> getMessages(String conversationId, {int limit = 100, int offset = 0}) async {
    final msgs = _messages[conversationId] ?? [];
    final sorted = [...msgs]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final start = offset.clamp(0, sorted.length);
    final end = (start + limit).clamp(0, sorted.length);
    return sorted.sublist(start, end);
  }

  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    _getController(conversationId);
    // Emit initial state
    Future.microtask(() => _emit(conversationId));
    return _controllers[conversationId]!.stream;
  }

  Future<void> insertMessage(ChatMessage msg) async {
    _messages.putIfAbsent(msg.conversationId, () => []);
    _messages[msg.conversationId]!.add(msg);

    // Update conversation metadata
    final conv = _conversations[msg.conversationId];
    if (conv != null) {
      _conversations[msg.conversationId] = conv.copyWith(
        updatedAt: msg.createdAt,
        messageCount: conv.messageCount + 1,
        totalTokens: conv.totalTokens + (msg.tokenCount ?? 0),
      );
    }
    // Notify listeners
    _emit(msg.conversationId);
  }

  Future<void> updateMessageContent(String messageId, String content) async {
    for (final msgs in _messages.values) {
      for (var i = 0; i < msgs.length; i++) {
        if (msgs[i].id == messageId) {
          msgs[i] = ChatMessage(
            id: msgs[i].id,
            conversationId: msgs[i].conversationId,
            role: msgs[i].role,
            content: content,
            toolCalls: msgs[i].toolCalls,
            toolCallId: msgs[i].toolCallId,
            tokenCount: msgs[i].tokenCount,
            createdAt: msgs[i].createdAt,
            metadata: msgs[i].metadata,
          );
          _emit(msgs[i].conversationId);
          return;
        }
      }
    }
  }

  Future<int> getMessageCount(String conversationId) async {
    return _messages[conversationId]?.length ?? 0;
  }

  Future<void> deleteMessages(String conversationId) async {
    _messages[conversationId]?.clear();
  }

  Future<void> close() async {
    for (final c in _controllers.values) {
      await c.close();
    }
    _controllers.clear();
    _conversations.clear();
    _messages.clear();
  }
}
