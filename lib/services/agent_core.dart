import 'dart:async';
import '../core/constants/ai_constants.dart';
import '../core/logger/app_logger.dart';
import '../services/llm_service.dart';
import '../services/evolution_engine.dart';
import '../services/memory_service.dart';
import '../services/conversation_service.dart';
import '../services/device_mesh_service.dart';

/// Agent action result.
class AgentActionResult {
  final String text;
  final List<Map<String, dynamic>> toolCalls;
  const AgentActionResult({this.text = '', this.toolCalls = const []});
}

/// Core AI agent — ties together LLM, evolution, memory, and device mesh.
class AgentService {
  final AppLogger _logger = AppLogger();
  final LlmService _llm;
  final EvolutionEngine _evolution;
  final MemoryService _memory;
  final DeviceMeshService _mesh;

  AgentService({
    required LlmService llm,
    required EvolutionEngine evolution,
    required MemoryService memory,
    required DeviceMeshService mesh,
  }) : _llm = llm, _evolution = evolution, _memory = memory, _mesh = mesh;

  EvolutionEngine get evolution => _evolution;
  MemoryService get memory => _memory;
  DeviceMeshService get mesh => _mesh;

  /// Process a user message and generate streaming response.
  Stream<String> processMessage({
    required String userMessage,
    required String conversationId,
    required ConversationService convService,
  }) async* {
    // 1. Recall relevant memories
    final memoryContext = _memory.getContextInjection(userMessage);

    // 2. Build context with memories injected
    final systemPrompt = AiConstants.defaultSystemPrompt + memoryContext;

    // 3. Get device mesh context
    final meshDevices = _mesh.knownDevices;
    String meshContext = '';
    if (meshDevices.isNotEmpty) {
      meshContext = '\n\n## 在线设备\n${meshDevices.map((d) => '- ${d.deviceName} (${d.deviceType}): ${d.capabilities.join(", ")}').join('\n')}';
    }

    // 4. Build API messages
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt + meshContext},
    ];

    // Add conversation history
    final history = await convService.buildApiContext(conversationId, maxMessages: 30);
    messages.addAll(history);

    // 5. Add available tools
    final tools = _evolution.functionSchemas;
    // Add built-in tools
    tools.addAll([
      {
        'type': 'function',
        'function': {
          'name': 'remember',
          'description': '记住一个关于用户的重要事实',
          'parameters': {
            'type': 'object',
            'properties': {
              'key': {'type': 'string', 'description': '记忆的键'},
              'value': {'type': 'string', 'description': '记忆的值'},
              'category': {'type': 'string', 'description': '分类: preference, fact, event, relationship, goal'},
            },
            'required': ['key', 'value', 'category'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'delegate_task',
          'description': '委托任务到另一台设备执行',
          'parameters': {
            'type': 'object',
            'properties': {
              'device_name': {'type': 'string', 'description': '目标设备名称'},
              'action': {'type': 'string', 'description': '要执行的操作'},
              'args': {'type': 'object', 'description': '操作参数'},
            },
            'required': ['device_name', 'action'],
          },
        },
      },
    ]);

    // 6. Call LLM with streaming
    try {
      await for (final chunk in _llm.chatStream(messages: messages, tools: tools)) {
        if (chunk.startsWith('__TOOL_CALL__')) {
          yield '\n🔧 ';
        } else {
          yield chunk;
        }
      }
    } catch (e) {
      _logger.error('Agent processing error', e);
      yield '\n\n❌ 出错了: ${e.toString().length > 80 ? e.toString().substring(0, 80) : e}';
    }
  }
}
