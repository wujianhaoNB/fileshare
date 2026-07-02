import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/ai_constants.dart';
import '../../core/logger/app_logger.dart';

/// Unified LLM client supporting DeepSeek API (OpenAI-compatible) and Ollama.
class LlmClient {
  final AppLogger _logger = AppLogger();

  String _baseUrl;
  String _apiKey;
  String _model;

  LlmClient({
    required String baseUrl,
    String apiKey = '',
    String model = '',
  })  : _baseUrl = baseUrl,
        _apiKey = apiKey,
        _model = model;

  factory LlmClient.deepseek({String apiKey = '', String? model}) {
    return LlmClient(
      baseUrl: AiConstants.deepseekBaseUrl,
      apiKey: apiKey,
      model: model ?? AiConstants.deepseekChatModel,
    );
  }

  factory LlmClient.ollama({String baseUrl = '', String? model}) {
    return LlmClient(
      baseUrl: baseUrl.isEmpty ? AiConstants.ollamaBaseUrl : baseUrl,
      model: model ?? AiConstants.ollamaDefaultModel,
    );
  }

  String get model => _model;

  void updateConfig({String? baseUrl, String? apiKey, String? model}) {
    if (baseUrl != null) _baseUrl = baseUrl;
    if (apiKey != null) _apiKey = apiKey;
    if (model != null) _model = model;
  }

  /// Non-streaming chat completion.
  Future<String> chat({
    required List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>>? tools,
    double temperature = 0.7,
    int maxTokens = 4096,
  }) async {
    final body = _buildRequestBody(messages, tools: tools, temperature: temperature, maxTokens: maxTokens, stream: false);

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/chat/completions'),
            headers: _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final choices = data['choices'] as List;
        if (choices.isNotEmpty) {
          return choices[0]['message']['content'] as String? ?? '';
        }
        return '';
      } else {
        _logger.error('LLM API error: ${response.statusCode} ${response.body}');
        throw LlmException('API error: ${response.statusCode}', response.body);
      }
    } catch (e) {
      if (e is LlmException) rethrow;
      _logger.error('LLM request failed', e);
      rethrow;
    }
  }

  /// Streaming chat completion. Yields content deltas as they arrive.
  Stream<String> chatStream({
    required List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>>? tools,
    double temperature = 0.7,
    int maxTokens = 4096,
  }) async* {
    final body = _buildRequestBody(messages, tools: tools, temperature: temperature, maxTokens: maxTokens, stream: true);

    try {
      final request = http.Request('POST', Uri.parse('$_baseUrl/chat/completions'))
        ..headers.addAll(_headers())
        ..body = jsonEncode(body);

      final streamedResponse = await http.Client().send(request);

      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        for (final line in chunk.split('\n')) {
          if (line.startsWith('data: ') && line.length > 6) {
            final data = line.substring(6).trim();
            if (data == '[DONE]') return;
            try {
              final json = jsonDecode(data);
              final choices = json['choices'] as List?;
              if (choices != null && choices.isNotEmpty) {
                final delta = choices[0]['delta'];
                if (delta != null) {
                  // Handle tool calls
                  final toolCalls = delta['tool_calls'] as List?;
                  if (toolCalls != null && toolCalls.isNotEmpty) {
                    yield '__TOOL_CALL__${jsonEncode(toolCalls)}';
                  }
                  // Handle text content
                  final content = delta['content'] as String?;
                  if (content != null && content.isNotEmpty) {
                    yield content;
                  }
                }
              }
            } catch (_) {
              // Skip malformed chunks
            }
          }
        }
      }
    } catch (e) {
      _logger.error('LLM stream failed', e);
      rethrow;
    }
  }

  Map<String, dynamic> _buildRequestBody(
    List<Map<String, dynamic>> messages, {
    List<Map<String, dynamic>>? tools,
    double temperature = 0.7,
    int maxTokens = 4096,
    bool stream = true,
  }) {
    final body = <String, dynamic>{
      'model': _model,
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'stream': stream,
    };

    if (tools != null && tools.isNotEmpty) {
      body['tools'] = tools;
      body['tool_choice'] = 'auto';
    }

    return body;
  }

  Map<String, String> _headers() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_apiKey';
    }
    return headers;
  }
}

class LlmException implements Exception {
  final String message;
  final String? body;
  LlmException(this.message, [this.body]);

  @override
  String toString() => 'LlmException: $message';
}
