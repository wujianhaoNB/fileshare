import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/ai_constants.dart';
import '../data/models/chat_message.dart';
import '../data/models/conversation.dart';
import '../data/repositories/chat_repository.dart';
import '../services/conversation_service.dart';
import '../services/llm_service.dart';
import '../services/evolution_engine.dart';
import '../services/memory_service.dart';
import '../services/device_mesh_service.dart';
import '../services/agent_core.dart';
import '../services/primitives/primitive_registry.dart';

// --- Foundation ---

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final repo = ChatRepository();
  ref.onDispose(() => repo.close());
  return repo;
});

final llmServiceProvider = Provider<LlmService>((ref) => LlmService());

final conversationServiceProvider = Provider<ConversationService>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  return ConversationService(repository: repo);
});

// --- Primitive & Evolution ---

final primitiveRegistryProvider = Provider<PrimitiveRegistry>((ref) {
  final reg = PrimitiveRegistry.createDefault();
  // Add a "notify_user" primitive for AI to push notifications
  reg.register(_NotifyPrimitive());
  return reg;
});

final evolutionEngineProvider = Provider<EvolutionEngine>((ref) {
  final primitives = ref.watch(primitiveRegistryProvider);
  return EvolutionEngine(primitives: primitives);
});

// --- Memory ---

final memoryServiceProvider = Provider<MemoryService>((ref) => MemoryService());

// --- Device Mesh ---

final deviceMeshServiceProvider = Provider<DeviceMeshService>((ref) {
  final mesh = DeviceMeshService();
  ref.onDispose(() => mesh.stop());
  return mesh;
});

// --- Agent ---

final agentServiceProvider = Provider<AgentService>((ref) {
  return AgentService(
    llm: ref.watch(llmServiceProvider),
    evolution: ref.watch(evolutionEngineProvider),
    memory: ref.watch(memoryServiceProvider),
    mesh: ref.watch(deviceMeshServiceProvider),
  );
});

// --- State ---

final activeConversationIdProvider = StateProvider<String?>((ref) => null);

final activeMessagesProvider = StreamProvider<List<ChatMessage>>((ref) {
  final convId = ref.watch(activeConversationIdProvider);
  if (convId == null) return Stream.value([]);
  return ref.watch(conversationServiceProvider).watchMessages(convId);
});

final isGeneratingProvider = StateProvider<bool>((ref) => false);
final streamingTextProvider = StateProvider<String>((ref) => '');

final availableModelsProvider = Provider<List<ModelOption>>((ref) => [
  ModelOption(id: AiConstants.deepseekChatModel, name: 'DeepSeek V3', provider: 'deepseek'),
  ModelOption(id: AiConstants.deepseekReasonerModel, name: 'DeepSeek R1', provider: 'deepseek'),
  ModelOption(id: 'qwen2.5:7b', name: 'Qwen2.5 7B (本地)', provider: 'ollama'),
]);

final selectedModelProvider = StateProvider<ModelOption>((ref) => ModelOption(
  id: AiConstants.deepseekChatModel, name: 'DeepSeek V3', provider: 'deepseek',
));

final apiKeyProvider = StateProvider<String>((ref) => '');

// Mesh devices stream
final meshDevicesProvider = StreamProvider<List<DeviceCapability>>((ref) {
  return ref.watch(deviceMeshServiceProvider).devices;
});

// Memory stats
final memoryStatsProvider = Provider<Map<String, int>>((ref) {
  return ref.watch(memoryServiceProvider).categoryCounts;
});

class ModelOption {
  final String id, name, provider;
  const ModelOption({required this.id, required this.name, required this.provider});
}

/// Built-in notify primitive — AI can show notifications to the user.
class _NotifyPrimitive extends Primitive {
  @override String get name => 'notify_user';
  @override String get description => '向用户显示通知消息';
  @override Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'title': {'type': 'string'},
      'body': {'type': 'string'},
    },
    'required': ['title', 'body'],
  };
  @override Future<PrimitiveResult> execute(Map<String, dynamic> args) async {
    return PrimitiveResult(success: true, data: {'title': args['title'], 'body': args['body']});
  }
}
