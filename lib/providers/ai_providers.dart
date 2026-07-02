import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/ai_constants.dart';
import '../data/models/chat_message.dart';
import '../data/models/conversation.dart';
import '../data/models/smart_home_device.dart';
import '../data/repositories/chat_repository.dart';
import '../services/conversation_service.dart';
import '../services/llm_service.dart';
import '../services/evolution_engine.dart';
import '../services/memory_service.dart';
import '../services/device_mesh_service.dart';
import '../services/agent_core.dart';
import '../services/smart_home_service.dart';
import '../services/automation_service.dart';
import '../services/personal_development_service.dart';
import '../platform/phone_integration.dart';
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
  ModelOption(id: AiConstants.deepseekChatModel, name: 'DeepSeek V4 Pro', provider: 'deepseek'),
  ModelOption(id: AiConstants.deepseekReasonerModel, name: 'DeepSeek V3', provider: 'deepseek'),
  ModelOption(id: 'qwen2.5:7b', name: 'Qwen2.5 7B (鏈湴)', provider: 'ollama'),
]);

final selectedModelProvider = StateProvider<ModelOption>((ref) => ModelOption(
  id: AiConstants.deepseekChatModel, name: 'DeepSeek V4 Pro', provider: 'deepseek',
));

final apiKeyProvider = StateProvider<String>((ref) => 'sk-047069f5f23644cfa164563f60a48465');

// Mesh devices stream
final meshDevicesProvider = StreamProvider<List<DeviceCapability>>((ref) {
  return ref.watch(deviceMeshServiceProvider).devices;
});

// Memory stats
final memoryStatsProvider = Provider<Map<String, int>>((ref) {
  return ref.watch(memoryServiceProvider).categoryCounts;
});

// --- Smart Home ---

final smartHomeServiceProvider = Provider<SmartHomeService>((ref) {
  final svc = SmartHomeService();
  ref.onDispose(() => svc.stop());
  return svc;
});

final smartHomeDevicesProvider = StreamProvider<List<SmartHomeDevice>>((ref) {
  return ref.watch(smartHomeServiceProvider).devices;
});

// --- Automation ---

final automationServiceProvider = Provider<AutomationService>((ref) {
  final primitives = ref.watch(primitiveRegistryProvider);
  final svc = AutomationService(primitives: primitives);
  ref.onDispose(() => svc.stop());
  return svc;
});

final automationRulesProvider = StreamProvider<List<AutomationRule>>((ref) {
  return ref.watch(automationServiceProvider).rules;
});

// --- Personal Development ---

final personalDevelopmentProvider = Provider<PersonalDevelopmentService>((ref) {
  final svc = PersonalDevelopmentService();
  svc.initDefaultDimensions();
  return svc;
});

final userProfileScoreProvider = Provider<double>((ref) {
  return ref.watch(personalDevelopmentProvider).overallScore;
});

// --- Phone Integration ---

final phoneIntegrationProvider = Provider<PhoneIntegrationService>((ref) {
  final svc = PhoneIntegrationService();
  ref.onDispose(() => svc.stop());
  return svc;
});

final phoneNotificationsProvider = StreamProvider<List<PhoneNotification>>((ref) {
  return ref.watch(phoneIntegrationProvider).notifications.map((n) => [n]);
});

class ModelOption {
  final String id, name, provider;
  const ModelOption({required this.id, required this.name, required this.provider});
}

/// Built-in notify primitive 鈥?AI can show notifications to the user.
class _NotifyPrimitive extends Primitive {
  @override String get name => 'notify_user';
  @override String get description => '鍚戠敤鎴锋樉绀洪€氱煡娑堟伅';
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
