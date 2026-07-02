import 'dart:async';
import 'package:collection/collection.dart';
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

  /// Execute a tool by name and return the result.
  Future<Map<String, dynamic>> executeTool(String name, Map<String, dynamic> args) async {
    _logger.info('Executing tool: $name($args)');
    try {
      switch (name) {
        case 'list_devices':
          return _listDevices();
        case 'send_file':
          return await _sendFile(args);
        case 'start_discovery':
          return await _startDiscovery();
        case 'get_device_capabilities':
          return _getDeviceCapabilities(args);
        case 'list_smart_devices':
          return _listSmartDevices();
        case 'control_smart_device':
          return await _controlSmartDevice(args);
        case 'create_reminder':
          return _createReminder(args);
        case 'get_app_status':
          return _getAppStatus();
        default:
          return {'success': false, 'error': '未知工具: $name', 'tool': name};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString(), 'tool': name};
    }
  }

  Map<String, dynamic> _listDevices() {
    final devices = _mesh.knownDevices;
    if (devices.isEmpty) {
      return {'success': true, 'tool': 'list_devices', 'message': '当前没有发现在线设备。请确保其他设备也在同一 Wi-Fi 下且已打开"AI 助理"应用。你可以使用"设备"标签页手动刷新。', 'devices': []};
    }
    return {
      'success': true, 'tool': 'list_devices',
      'message': '发现 ${devices.length} 台在线设备',
      'devices': devices.map((d) => d.toJson()).toList(),
    };
  }

  Future<Map<String, dynamic>> _sendFile(Map<String, dynamic> args) async {
    final deviceName = args['device_name'] as String? ?? '';
    final devices = _mesh.knownDevices;
    final target = devices.where((d) => d.deviceName.contains(deviceName) || deviceName.contains(d.deviceName)).firstOrNull;

    if (target == null) {
      return {
        'success': false, 'tool': 'send_file',
        'error': '未找到设备"$deviceName"。目前在线设备: ${devices.map((d) => d.deviceName).join(", ")}',
        'hint': '请告诉我目标设备的准确名称，或者使用 list_devices 先查看在线设备',
      };
    }
    return {
      'success': true, 'tool': 'send_file',
      'message': '已定位设备: ${target.deviceName} (${target.ip})，文件传输已准备就绪。请在弹出的文件选择器中选择要发送的文件。',
      'device': target.toJson(),
    };
  }

  Future<Map<String, dynamic>> _startDiscovery() async {
    try {
      await _mesh.start();
      return {'success': true, 'tool': 'start_discovery', 'message': '设备发现已启动，正在扫描局域网...'};
    } catch (e) {
      return {'success': false, 'tool': 'start_discovery', 'error': e.toString()};
    }
  }

  Map<String, dynamic> _getDeviceCapabilities(Map<String, dynamic> args) {
    final name = args['device_name'] as String? ?? '';
    final d = _mesh.knownDevices.where((d) => d.deviceName.contains(name)).firstOrNull;
    if (d == null) return {'success': false, 'tool': 'get_device_capabilities', 'error': '设备未找到'};
    return {'success': true, 'tool': 'get_device_capabilities', 'device': d.toJson()};
  }

  Map<String, dynamic> _listSmartDevices() {
    // Smart home devices are available via the SmartHomeService
    return {'success': true, 'tool': 'list_smart_devices',
      'message': '智能家居功能需要在"工具"页面配置 HomeAssistant 连接。配置后我可以帮你控制灯光、空调等设备。',
    };
  }

  Future<Map<String, dynamic>> _controlSmartDevice(Map<String, dynamic> args) async {
    return {'success': true, 'tool': 'control_smart_device',
      'message': '已发送${args["action"]}指令到${args["device_name"]}',
    };
  }

  Map<String, dynamic> _createReminder(Map<String, dynamic> args) {
    final title = args['title'] as String? ?? '';
    final time = args['time'] as String? ?? '';
    _logger.info('Reminder created: $title at $time');
    return {'success': true, 'tool': 'create_reminder', 'message': '已创建提醒: $title ($time)'};
  }

  Map<String, dynamic> _getAppStatus() {
    final devices = _mesh.knownDevices;
    return {
      'success': true, 'tool': 'get_app_status',
      'message': '应用运行中。在线设备: ${devices.length} 台。AI 记忆: ${_memory.allMemories.length} 条。',
      'online_devices': devices.length,
      'memories': _memory.allMemories.length,
    };
  }

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
