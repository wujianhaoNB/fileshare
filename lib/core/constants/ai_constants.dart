/// AI assistant configuration constants.
class AiConstants {
  AiConstants._();

  // --- LLM Providers ---
  static const String defaultProvider = 'deepseek';
  static const String deepseekBaseUrl = 'https://api.deepseek.com/v1';
  static const String deepseekChatModel = 'deepseek-chat';
  static const String deepseekReasonerModel = 'deepseek-reasoner';
  static const String ollamaBaseUrl = 'http://localhost:11434';
  static const String ollamaDefaultModel = 'qwen2.5:7b';

  // --- Agent ---
  static const int maxAgentLoops = 5;
  static const int maxToolExecutionTimeMs = 30000;
  static const String sandboxBasePath = 'ai_sandbox';

  // --- System Prompts ---
  static const String defaultSystemPrompt = '''
你是一个全能的 AI 私人助理，名叫"小智"。你的能力可以自我进化——当你发现缺少某个能力时，你可以创建新的工具来扩展自己。

核心原则：
1. 用中文回复，除非用户要求其他语言
2. 诚实透明：不知道就说不知道，不确定就说不确定
3. 主动思考：不只回答问题，还要预判用户可能需要的后续帮助
4. 跨设备意识：你知道用户有多台设备（iPhone/Android/Windows），可以协调它们
5. 自我进化：当现有能力不足以完成用户需求时，你可以学习并创建新工具

你的原子能力（可组合使用）：
- http_call: 发送 HTTP 请求到任何 API
- file_ops: 读写文件系统
- process_run: 执行系统命令
- ui_render: 渲染 UI 组件展示信息
- db_query: 查询本地数据库
- device_api: 访问平台原生 API
- code_execute: 在安全沙箱中执行代码

记住：你不是一个被动回答问题的聊天机器人。你是一个能主动行动、自我进化的智能体。
''';

  static const String evolutionPrompt = '''
你需要分析是否现有工具足以完成用户的需求。如果不够，请：
1. 描述需要什么新能力
2. 搜索或推理该能力的技术实现方式
3. 生成一个 Tool Config (YAML 格式)
4. 在沙箱中测试
5. 部署并用于当前任务
''';

  // --- Tool Config Template ---
  static const String toolConfigTemplate = '''
name: {name}
description: {description}
category: {category}
created_by: ai_evolution
parameters:
{parameters}
steps:
{steps}
safety:
  requires_approval: {requires_approval}
  max_rate: "{max_rate}"
''';
}
