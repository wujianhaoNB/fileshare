/// Represents a single message in a conversation.
class ChatMessage {
  final String id;
  final String conversationId;
  final String role; // 'user', 'assistant', 'system', 'tool'
  final String content;
  final String? toolCalls; // JSON array of tool calls
  final String? toolCallId; // For tool result messages
  final int? tokenCount;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.toolCalls,
    this.toolCallId,
    this.tokenCount,
    required this.createdAt,
    this.metadata,
  });

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
  bool get isSystem => role == 'system';
  bool get isTool => role == 'tool';

  /// Convert to the format expected by LLM APIs.
  Map<String, dynamic> toApiFormat() {
    final msg = <String, dynamic>{
      'role': role,
      'content': content,
    };
    if (toolCalls != null) {
      msg['tool_calls'] = toolCalls;
    }
    if (toolCallId != null) {
      msg['tool_call_id'] = toolCallId;
    }
    return msg;
  }
}
