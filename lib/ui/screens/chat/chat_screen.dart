import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/ai_constants.dart';
import '../../../data/models/chat_message.dart';
import '../../../providers/ai_providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with TickerProviderStateMixin {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _uuid = const Uuid();
  bool _showWelcome = true;

  @override
  void initState() {
    super.initState();
    // Only create a conversation if there isn't one already
    // (prevents losing chat history when switching tabs)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final existingId = ref.read(activeConversationIdProvider);
      if (existingId == null) {
        _initConversation();
      }
    });
  }

  Future<void> _initConversation() async {
    final svc = ref.read(conversationServiceProvider);
    final conv = await svc.createConversation();
    ref.read(activeConversationIdProvider.notifier).state = conv.id;
    setState(() => _showWelcome = true);
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    _showWelcome = false;
    final convId = ref.read(activeConversationIdProvider);
    if (convId == null) return;

    final convService = ref.read(conversationServiceProvider);
    final llmService = ref.read(llmServiceProvider);
    final agent = ref.read(agentServiceProvider);
    final model = ref.read(selectedModelProvider);
    llmService.setModel(model.id);
    llmService.setApiKey(ref.read(apiKeyProvider));

    await convService.addUserMessage(convId, text);
    final assistantMsg = await convService.createAssistantMessage(convId);

    ref.read(isGeneratingProvider.notifier).state = true;
    ref.read(streamingTextProvider.notifier).state = '';

    final buffer = StringBuffer();

    try {
      // STEP 1: Parse user intent LOCALLY and execute tools BEFORE LLM
      final toolResults = <Map<String, dynamic>>[];
      final triggeredTools = _matchIntent(text);

      if (triggeredTools.isNotEmpty) {
        for (final tool in triggeredTools) {
          buffer.write('\n\n🔧 **${_toolLabel(tool)}**');
          ref.read(streamingTextProvider.notifier).state = buffer.toString();
          final result = await agent.executeTool(tool, {});
          toolResults.add(result);
          buffer.write(result['success'] == true ? ' ✓\n' : ' ✗\n');
          ref.read(streamingTextProvider.notifier).state = buffer.toString();
        }
      }

      // STEP 2: Build context — add recent history first, then current tool results
      final messages = <Map<String, dynamic>>[
        {'role': 'system', 'content': AiConstants.defaultSystemPrompt},
      ];

      // Add conversation history (last 20 messages for context)
      final history = await convService.getMessages(convId, limit: 20);
      for (final msg in history) {
        messages.add(msg.toApiFormat());
      }

      // Remove the last user message (it's the current one, already in history)
      // and inject tool results before it so LLM sees results first
      if (toolResults.isNotEmpty && messages.length >= 2) {
        final toolMsg = '[系统: 已自动执行以下操作 — ${toolResults.map((r) => "${r["tool"]}: ${r["success"] == true ? "成功" : "失败"}。${r["message"] ?? ""}").join(" | ")}]';
        // Remove last user+assistant if they exist (will be regenerated)
        if (messages.last['role'] == 'user') {
          messages.removeLast();
        }
        messages.add({'role': 'user', 'content': '$text\n\n$toolMsg'});
      }

      // STEP 3: LLM generates natural response based on real data
      try {
        await for (final chunk in llmService.client.chatStream(messages: messages, temperature: 0.7, maxTokens: 1024)) {
          buffer.write(chunk.startsWith('__TOOL_CALL__') ? '' : chunk);
          ref.read(streamingTextProvider.notifier).state = buffer.toString();
        }
      } catch (_) {
        // Fallback: non-streaming
        try {
          final resp = await llmService.client.chat(messages: messages, temperature: 0.7, maxTokens: 1024);
          buffer.write(resp);
          ref.read(streamingTextProvider.notifier).state = buffer.toString();
        } catch (e2) {
          buffer.write('\n\n❌ ${e2.toString().substring(0, 100)}');
        }
      }
    } catch (e) {
      buffer.write('\n\n❌ ${e.toString().substring(0, 100)}');
    }

    final finalText = buffer.toString();
    await convService.updateAssistantContent(assistantMsg.id, finalText.isEmpty ? '好的，我理解你的需求。让我知道更多细节以便更好地帮助你。' : finalText);
    ref.read(isGeneratingProvider.notifier).state = false;
    ref.read(streamingTextProvider.notifier).state = '';
    _scrollDown();
  }

  /// Build the tool definitions for LLM function calling.
  List<Map<String, dynamic>> _buildTools() {
    return [
      _toolDef('list_devices', '获取当前局域网内所有在线设备列表，包括设备名称、IP、类型和可用能力', {
        'type': 'object', 'properties': {}, 'required': [],
      }),
      _toolDef('send_file', '发送文件到指定设备。需要目标设备的名称', {
        'type': 'object',
        'properties': {
          'device_name': {'type': 'string', 'description': '目标设备名称，如"我的电脑"'},
        },
        'required': ['device_name'],
      }),
      _toolDef('start_discovery', '启动/刷新设备发现，扫描局域网内的设备', {
        'type': 'object', 'properties': {}, 'required': [],
      }),
      _toolDef('get_device_capabilities', '查询某台设备的详细能力列表', {
        'type': 'object',
        'properties': {'device_name': {'type': 'string'}},
        'required': ['device_name'],
      }),
      _toolDef('list_smart_devices', '获取智能家居设备列表', {
        'type': 'object', 'properties': {}, 'required': [],
      }),
      _toolDef('control_smart_device', '控制智能家居设备开关或调节', {
        'type': 'object',
        'properties': {
          'device_name': {'type': 'string'},
          'action': {'type': 'string', 'enum': ['turn_on', 'turn_off', 'toggle']},
        },
        'required': ['device_name', 'action'],
      }),
      _toolDef('create_reminder', '创建一个定时提醒', {
        'type': 'object',
        'properties': {
          'title': {'type': 'string', 'description': '提醒标题'},
          'time': {'type': 'string', 'description': '提醒时间，如 "18:30" 或 "in 30 minutes"'},
        },
        'required': ['title', 'time'],
      }),
      _toolDef('get_app_status', '查询当前应用的运行状态，包括服务器是否启动、已配对设备数量、传输历史等', {
        'type': 'object', 'properties': {}, 'required': [],
      }),
    ];
  }

  Map<String, dynamic> _toolDef(String name, String desc, Map<String, dynamic> params) {
    return {
      'type': 'function',
      'function': {'name': name, 'description': desc, 'parameters': params},
    };
  }

  String _toolLabel(String name) {
    switch (name) {
      case 'list_devices': return '正在扫描在线设备...';
      case 'send_file': return '正在准备文件传输...';
      case 'start_discovery': return '正在启动设备发现...';
      case 'get_device_capabilities': return '正在查询设备能力...';
      case 'list_smart_devices': return '正在获取智能设备列表...';
      case 'control_smart_device': return '正在控制设备...';
      case 'create_reminder': return '正在创建提醒...';
      case 'get_app_status': return '正在查询应用状态...';
      default: return '正在执行 $name...';
    }
  }

  /// Parse LLM response into text + tool calls.
  _ParsedResponse _parseToolCalls(String response) {
    try {
      final json = jsonDecode(response);
      final choices = json['choices'] as List?;
      if (choices == null || choices.isEmpty) return _ParsedResponse(text: response);

      final message = choices[0]['message'];
      if (message == null) return _ParsedResponse(text: response);

      final content = message['content'] as String? ?? '';
      final toolCalls = (message['tool_calls'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      return _ParsedResponse(text: content, toolCalls: toolCalls);
    } catch (_) {
      return _ParsedResponse(text: response);
    }
  }

  /// Local intent matching — parse user input and decide which tools to call.
  /// Returns list of tool names to execute (BEFORE sending to LLM).
  List<String> _matchIntent(String input) {
    final tools = <String>[];
    final t = input.toLowerCase();

    // Device discovery / listing
    if (_hasAny(t, ['设备', '在线', '发现', '扫描', '连接', '平板', '电脑', '手机', '我的', '看看', '查看', '查找', '找到', '列出', '哪些', '几台', '什么设备', '连我', '连上', '发文件', '发送', '传输', '传文件', '传给', '传到', '发给', '发送给'])) {
      tools.add('list_devices');
    }
    // Smart home
    if (_hasAny(t, ['智能', '灯', '空调', '窗帘', '开关', '打开', '关闭', '调', '温度', '家居', 'home'])) {
      tools.add('list_smart_devices');
    }
    // App status
    if (_hasAny(t, ['状态', '运行', '怎么样', '信息', '版本', '情况'])) {
      tools.add('get_app_status');
    }

    // Dedup
    return tools.toSet().toList();
  }

  bool _hasAny(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }

  /// Detect if LLM is "faking" an action — saying it will do something without actually calling a tool.
  String? _detectImpliedAction(String text) {
    final t = text.toLowerCase();
    if (t.contains('扫描') || t.contains('发现设备') || t.contains('查找设备') || t.contains('scan')) return 'list_devices';
    if (t.contains('发文件') || t.contains('传输') || t.contains('发送文件') || t.contains('send file')) return 'send_file';
    if (t.contains('在线设备') || t.contains('设备列表')) return 'list_devices';
    if (t.contains('状态') || t.contains('运行')) return 'get_app_status';
    return null;
  }

  String _summarizeResult(String tool, Map<String, dynamic> result) {
    if (tool == 'list_devices') {
      final devices = result['devices'] as List? ?? [];
      if (devices.isEmpty) return '当前没有发现在线设备。请确保其他设备已打开并连接同一 Wi-Fi。';
      final names = devices.map((d) => d['device_name'] ?? '').where((n) => n.isNotEmpty).join('、');
      return '发现 ${devices.length} 台在线设备: $names';
    }
    return result['message'] as String? ?? '操作完成';
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
      }
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      action: SnackBarAction(label: '设置', onPressed: () {}),
    ));
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(activeMessagesProvider);
    final isGenerating = ref.watch(isGeneratingProvider);
    final streamingText = ref.watch(streamingTextProvider);
    final convId = ref.watch(activeConversationIdProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0xFF0D0D14), Color(0xFF0A0A10), Color(0xFF0D0D14)],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0xFFFAFAFE), Color(0xFFF5F5FB), Color(0xFFFAFAFE)],
                ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(theme),
              Expanded(
                child: messagesAsync.when(
                  data: (msgs) => _showWelcome && msgs.isEmpty && streamingText.isEmpty
                      ? _buildWelcome(theme)
                      : _buildMessages(theme, msgs, streamingText, isGenerating, convId ?? ''),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e,_) => Center(child: Text('加载失败', style: theme.textTheme.bodyMedium)),
                ),
              ),
              _buildInputBar(theme, isGenerating),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ──
  Widget _buildHeader(ThemeData theme) {
    final model = ref.watch(selectedModelProvider);
    final options = ref.watch(availableModelsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(colors: [Color(0xFF7C5CFC), Color(0xFF00CEC9)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _showModelPicker(context, options, model),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(model.name, style: theme.textTheme.titleMedium),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF8B8A9A)),
                ],
              ),
            ),
          ),
          _HeaderIcon(icon: Icons.add_rounded, tooltip: '新对话', onTap: () async {
            final svc = ref.read(conversationServiceProvider);
            final c = await svc.createConversation();
            ref.read(activeConversationIdProvider.notifier).state = c.id;
            setState(() => _showWelcome = true);
          }),
          const SizedBox(width: 4),
          _HeaderIcon(icon: Icons.settings_outlined, tooltip: '设置', onTap: () {}),
        ],
      ),
    );
  }

  void _showModelPicker(BuildContext context, List<ModelOption> models, ModelOption current) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: const Color(0xFF8B8A9A).withValues(alpha: 0.3))),
            ...models.map((m) => ListTile(
              leading: Icon(m.provider == 'ollama' ? Icons.computer_rounded : Icons.cloud_rounded,
                color: m.id == current.id ? const Color(0xFF7C5CFC) : null),
              title: Text(m.name, style: TextStyle(fontWeight: m.id == current.id ? FontWeight.w600 : FontWeight.w400)),
              trailing: m.id == current.id ? const Icon(Icons.check_rounded, color: Color(0xFF7C5CFC)) : null,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              onTap: () {
                ref.read(selectedModelProvider.notifier).state = m;
                Navigator.pop(ctx);
              },
            )),
          ],
        ),
      ),
    );
  }

  // ── Welcome ──
  Widget _buildWelcome(ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(colors: [Color(0xFF7C5CFC), Color(0xFF00CEC9)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                boxShadow: [BoxShadow(color: const Color(0xFF7C5CFC).withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 8))],
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 28),
            Text('你好，我是小智', style: theme.textTheme.displayLarge?.copyWith(fontSize: 28)),
            const SizedBox(height: 10),
            Text('你的全能 AI 私人助理\n可以聊天、管理文件、控制设备、处理任务', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15, height: 1.6)),
            const SizedBox(height: 32),
            Wrap(spacing: 10, runSpacing: 10, children: [
              _SuggestionChip(icon: Icons.swap_horiz_rounded, label: '发送文件给电脑', onTap: () => _quickSend('帮我把文件传到电脑')),
              _SuggestionChip(icon: Icons.cloud_outlined, label: '今天天气怎么样', onTap: () => _quickSend('今天天气怎么样？')),
              _SuggestionChip(icon: Icons.notifications_outlined, label: '摘要我的通知', onTap: () {}),
              _SuggestionChip(icon: Icons.schedule_rounded, label: '帮我设个提醒', onTap: () => _quickSend('帮我设置一个提醒')),
            ]),
          ],
        ),
      ),
    );
  }

  void _quickSend(String text) {
    _textController.text = text;
    _sendMessage();
  }

  // ── Messages ──
  Widget _buildMessages(ThemeData theme, List<ChatMessage> msgs, String streaming, bool generating, String convId) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: msgs.length + (streaming.isNotEmpty ? 1 : 0),
      itemBuilder: (_, i) {
        if (i < msgs.length) return _MsgBubble(msg: msgs[i], theme: theme);
        return _MsgBubble(msg: ChatMessage(id: 's', conversationId: convId, role: 'assistant', content: streaming, createdAt: DateTime.now()), theme: theme, streaming: true);
      },
    );
  }

  // ── Input ──
  Widget _buildInputBar(ThemeData theme, bool generating) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                maxLines: 5, minLines: 1,
                style: theme.textTheme.bodyLarge,
                decoration: const InputDecoration(
                  hintText: '输入消息...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  filled: false,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: generating
                  ? Padding(
                      padding: const EdgeInsets.only(right: 12, bottom: 8),
                      child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: theme.colorScheme.primary)),
                    )
                  : IconButton(
                      onPressed: _sendMessage,
                      icon: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(colors: [Color(0xFF7C5CFC), Color(0xFF00CEC9)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        ),
                        child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header icon button ──
class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _HeaderIcon({required this.icon, required this.tooltip, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 20, color: const Color(0xFF8B8A9A)),
          ),
        ),
      ),
    );
  }
}

// ── Suggestion chip ──
class _SuggestionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SuggestionChip({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08)),
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: const Color(0xFF7C5CFC)),
              const SizedBox(width: 8),
              Text(label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Message bubble ──
class _MsgBubble extends StatelessWidget {
  final ChatMessage msg;
  final ThemeData theme;
  final bool streaming;
  const _MsgBubble({required this.msg, required this.theme, this.streaming = false});
  @override
  Widget build(BuildContext context) {
    final isUser = msg.isUser;
    final w = MediaQuery.of(context).size.width;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(width: 28, height: 28, margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), gradient: const LinearGradient(colors: [Color(0xFF7C5CFC), Color(0xFF00CEC9)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 14)),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: w * 0.78),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? theme.colorScheme.primary.withValues(alpha: 0.12) : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4), bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
              ),
              child: isUser || msg.content.isEmpty
                  ? Text(msg.content.isEmpty ? '' : msg.content, style: theme.textTheme.bodyLarge)
                  : MarkdownBody(
                      data: msg.content,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                        code: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace', fontSize: 13, backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.5)),
                        codeblockDecoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(12)),
                        blockquoteDecoration: BoxDecoration(border: Border(left: BorderSide(color: const Color(0xFF7C5CFC), width: 2))),
                      ),
                    ),
            ),
          ),
          if (streaming)
            Padding(padding: const EdgeInsets.only(left: 6, bottom: 7), child: _TypingDots()),
        ],
      ),
    );
  }
}

// ── Response parser ──
class _ParsedResponse {
  final String text;
  final List<Map<String, dynamic>> toolCalls;
  const _ParsedResponse({this.text = '', this.toolCalls = const []});
}

// ── Typing indicator ──
class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}
class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat();
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        final opacity = (1.0 - (_ctrl.value - 0.5).abs() * 2.0).clamp(0.3, 1.0);
        return Opacity(opacity: opacity, child: child);
      },
      child: Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF7C5CFC))),
    );
  }
}
