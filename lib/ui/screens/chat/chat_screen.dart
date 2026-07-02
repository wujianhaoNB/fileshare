import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/ai_constants.dart';
import '../../../data/models/chat_message.dart';
import '../../../providers/ai_providers.dart';
import '../../../services/conversation_service.dart';
import '../../../services/llm_service.dart';

/// Main AI chat screen — the primary interface of the app.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _initConversation();
  }

  Future<void> _initConversation() async {
    final convService = ref.read(conversationServiceProvider);
    final conv = await convService.createConversation();
    ref.read(activeConversationIdProvider.notifier).state = conv.id;
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    if (ref.read(apiKeyProvider).isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先在设置中配置 DeepSeek API Key')),
        );
      }
      return;
    }

    _textController.clear();
    final convId = ref.read(activeConversationIdProvider);
    if (convId == null) return;

    // Add user message
    final convService = ref.read(conversationServiceProvider);
    await convService.addUserMessage(convId, text);

    // Update model selection
    final model = ref.read(selectedModelProvider);
    final llmService = ref.read(llmServiceProvider);
    llmService.setModel(model.id);
    llmService.setApiKey(ref.read(apiKeyProvider));

    // Create empty assistant message
    final assistantMsg = await convService.createAssistantMessage(convId);

    // Build API context
    final messages = await convService.buildApiContext(
      convId,
      systemPrompt: AiConstants.defaultSystemPrompt,
    );

    // Stream response
    ref.read(isGeneratingProvider.notifier).state = true;
    ref.read(streamingTextProvider.notifier).state = '';

    final buffer = StringBuffer();
    try {
      await for (final chunk in llmService.chatStream(messages: messages)) {
        if (chunk.startsWith('__TOOL_CALL__')) {
          // Tool calls will be handled in Phase 2
          buffer.write('\n\n🔧 _执行工具中..._');
        } else {
          buffer.write(chunk);
        }
        ref.read(streamingTextProvider.notifier).state = buffer.toString();
      }
    } catch (e) {
      buffer.write('\n\n❌ _错误: ${e}_');
    }

    // Save final content
    await convService.updateAssistantContent(assistantMsg.id, buffer.toString());
    ref.read(isGeneratingProvider.notifier).state = false;
    ref.read(streamingTextProvider.notifier).state = '';

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
    final model = ref.watch(selectedModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: model.id,
            isDense: true,
            items: ref.watch(availableModelsProvider).map((m) {
              return DropdownMenuItem(
                value: m.id,
                child: Text(m.name, style: const TextStyle(fontSize: 14)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                final selected = ref.read(availableModelsProvider).firstWhere((m) => m.id == value);
                ref.read(selectedModelProvider.notifier).state = selected;
              }
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新对话',
            onPressed: () async {
              final svc = ref.read(conversationServiceProvider);
              final conv = await svc.createConversation();
              ref.read(activeConversationIdProvider.notifier).state = conv.id;
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '设置',
            onPressed: () {},
          ),
        ],
      ),
      body: messagesAsync.when(
        data: (messages) {
          return Column(
            children: [
              Expanded(
                child: messages.isEmpty && streamingText.isEmpty
                    ? _buildEmptyState(context)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: messages.length + (streamingText.isNotEmpty ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index < messages.length) {
                            return _MessageBubble(message: messages[index]);
                          }
                          // Streaming message
                          return _MessageBubble(
                            message: ChatMessage(
                              id: 'streaming',
                              conversationId: convId ?? '',
                              role: 'assistant',
                              content: streamingText,
                              createdAt: DateTime.now(),
                            ),
                            isStreaming: true,
                          );
                        },
                      ),
              ),
              _buildInputBar(context, isGenerating),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('错误: $e')),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'AI 助理',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '我是你的全能私人助理，可以回答问题、\n管理文件、控制设备、处理任务。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickChip(icon: Icons.send, label: '发送文件', onTap: () {}),
              _QuickChip(icon: Icons.cloud, label: '查天气', onTap: () => _quickSend('帮我查一下今天的天气')),
              _QuickChip(icon: Icons.notifications, label: '摘要通知', onTap: () {}),
              _QuickChip(icon: Icons.schedule, label: '设提醒', onTap: () => _quickSend('帮我创建一个提醒')),
            ],
          ),
        ],
      ),
    );
  }

  void _quickSend(String text) {
    _textController.text = text;
    _sendMessage();
  }

  Widget _buildInputBar(BuildContext context, bool isGenerating) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.3),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                maxLines: 5,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: '输入消息...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  suffixIcon: IconButton(
                    icon: Icon(isGenerating ? Icons.stop : Icons.send_rounded),
                    onPressed: isGenerating ? null : _sendMessage,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick action chip.
class _QuickChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

/// Chat message bubble.
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isStreaming;
  const _MessageBubble({required this.message, this.isStreaming = false});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final alignment = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isUser
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
            ),
            child: isUser
                ? Text(message.content, style: Theme.of(context).textTheme.bodyLarge)
                : MarkdownBody(
                    data: message.content.isEmpty && isStreaming ? '...' : message.content,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: Theme.of(context).textTheme.bodyLarge,
                      code: TextStyle(
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  ),
          ),
          if (isStreaming)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
