import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/constants/ai_constants.dart';
import '../data/models/chat_message.dart';
import '../data/models/conversation.dart';
import '../data/repositories/chat_repository.dart';
import '../services/conversation_service.dart';
import '../services/llm_service.dart';

/// Chat repository singleton.
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final repo = ChatRepository();
  ref.onDispose(() => repo.close());
  return repo;
});

/// LLM service singleton.
final llmServiceProvider = Provider<LlmService>((ref) {
  return LlmService();
});

/// Conversation service singleton.
final conversationServiceProvider = Provider<ConversationService>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  return ConversationService(repository: repo);
});

/// Active conversation ID.
final activeConversationIdProvider = StateProvider<String?>((ref) => null);

/// Messages for the active conversation.
final activeMessagesProvider = StreamProvider<List<ChatMessage>>((ref) {
  final convId = ref.watch(activeConversationIdProvider);
  if (convId == null) return Stream.value([]);
  final svc = ref.watch(conversationServiceProvider);
  return svc.watchMessages(convId);
});

/// Whether the AI is currently generating a response.
final isGeneratingProvider = StateProvider<bool>((ref) => false);

/// Current streaming text (shown in real-time in the UI).
final streamingTextProvider = StateProvider<String>((ref) => '');

/// List of available models.
final availableModelsProvider = Provider<List<ModelOption>>((ref) => [
  ModelOption(id: AiConstants.deepseekChatModel, name: 'DeepSeek V3 (云端)', provider: 'deepseek'),
  ModelOption(id: AiConstants.deepseekReasonerModel, name: 'DeepSeek R1 (推理)', provider: 'deepseek'),
  ModelOption(id: 'qwen2.5:7b', name: 'Qwen2.5 7B (本地)', provider: 'ollama'),
]);

/// Selected model.
final selectedModelProvider = StateProvider<ModelOption>((ref) => ModelOption(
  id: AiConstants.deepseekChatModel,
  name: 'DeepSeek V3 (云端)',
  provider: 'deepseek',
));

/// DeepSeek API key.
final apiKeyProvider = StateProvider<String>((ref) => '');

class ModelOption {
  final String id;
  final String name;
  final String provider;
  const ModelOption({required this.id, required this.name, required this.provider});
}
