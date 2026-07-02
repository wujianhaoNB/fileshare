import 'dart:async';
import '../core/constants/ai_constants.dart';
import '../core/logger/app_logger.dart';
import '../network/llm/llm_client.dart';

/// Manages LLM invocation, model switching, and fallback.
class LlmService {
  final AppLogger _logger = AppLogger();

  LlmClient? _client;
  String _currentModel = AiConstants.deepseekChatModel;
  String _apiKey = '';

  /// Set the API key for DeepSeek.
  void setApiKey(String key) {
    _apiKey = key;
    _client = null; // Force re-creation
  }

  /// Set the current model.
  void setModel(String model) {
    _currentModel = model;
    _client = null;
  }

  String get currentModel => _currentModel;

  LlmClient get client {
    if (_client != null) return _client!;
    _client = LlmClient.deepseek(
      apiKey: _apiKey,
      model: _currentModel,
    );
    return _client!;
  }

  /// Get a non-streaming completion.
  Future<String> chat({
    required List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>>? tools,
  }) async {
    try {
      return await client.chat(
        messages: messages,
        tools: tools,
      );
    } catch (e) {
      _logger.error('LLM chat failed', e);
      rethrow;
    }
  }

  /// Get a streaming completion.
  /// Yields content chunks as they arrive. Tool call chunks are prefixed with __TOOL_CALL__.
  Stream<String> chatStream({
    required List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>>? tools,
  }) {
    return client.chatStream(
      messages: messages,
      tools: tools,
    );
  }

  /// Test connectivity to the configured LLM backend.
  Future<bool> testConnection() async {
    try {
      await client.chat(
        messages: [
          {'role': 'user', 'content': 'ping'},
        ],
        maxTokens: 10,
      );
      return true;
    } catch (e) {
      _logger.error('LLM connection test failed', e);
      return false;
    }
  }
}
