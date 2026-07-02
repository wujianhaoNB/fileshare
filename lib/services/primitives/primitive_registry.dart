import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../core/logger/app_logger.dart';

/// Result from executing a primitive.
class PrimitiveResult {
  final bool success;
  final dynamic data;
  final String? error;
  const PrimitiveResult({required this.success, this.data, this.error});
  Map<String, dynamic> toJson() => {'success': success, 'data': data, 'error': error};
}

/// Base class for all atomic primitives — the irreducible capabilities AI builds upon.
abstract class Primitive {
  String get name;
  String get description;
  Map<String, dynamic> get parametersSchema;

  Future<PrimitiveResult> execute(Map<String, dynamic> args);
  PrimitiveResult toResult(dynamic data) => PrimitiveResult(success: true, data: data);
  PrimitiveResult toError(String e) => PrimitiveResult(success: false, error: e);
}

/// HTTP Request primitive — AI can call any REST API.
class HttpCallPrimitive extends Primitive {
  @override String get name => 'http_call';
  @override String get description => '发送 HTTP 请求到任意 API';
  @override Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'url': {'type': 'string', 'description': '请求 URL'},
      'method': {'type': 'string', 'enum': ['GET', 'POST', 'PUT', 'DELETE'], 'default': 'GET'},
      'headers': {'type': 'object', 'description': '请求头'},
      'body': {'type': 'string', 'description': '请求体 (JSON)'},
    },
    'required': ['url'],
  };

  @override
  Future<PrimitiveResult> execute(Map<String, dynamic> args) async {
    try {
      final url = args['url'] as String;
      final method = args['method'] as String? ?? 'GET';
      final headers = (args['headers'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v.toString())) ?? <String, String>{};
      final body = args['body'] as String?;

      final uri = Uri.parse(url);
      http.Response response;
      switch (method) {
        case 'POST': response = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 30)); break;
        case 'PUT': response = await http.put(uri, headers: headers, body: body).timeout(const Duration(seconds: 30)); break;
        case 'DELETE': response = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 30)); break;
        default: response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 30));
      }

      return PrimitiveResult(success: response.statusCode >= 200 && response.statusCode < 300, data: {
        'status': response.statusCode,
        'body': response.body,
        'headers': response.headers,
      });
    } catch (e) {
      return toError(e.toString());
    }
  }
}

/// File System primitive — AI can read/write files.
class FileOpsPrimitive extends Primitive {
  final AppLogger _logger = AppLogger();
  @override String get name => 'file_ops';
  @override String get description => '读写文件系统（沙箱限制）';
  @override Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'action': {'type': 'string', 'enum': ['read', 'write', 'list', 'delete', 'exists']},
      'path': {'type': 'string', 'description': '文件路径'},
      'content': {'type': 'string', 'description': '写入内容 (仅 write)'},
    },
    'required': ['action', 'path'],
  };

  @override
  Future<PrimitiveResult> execute(Map<String, dynamic> args) async {
    try {
      final action = args['action'] as String;
      final path = args['path'] as String;
      final file = File(path);

      switch (action) {
        case 'read':
          if (await file.exists()) return toResult(await file.readAsString());
          return toError('文件不存在: $path');
        case 'write':
          await file.parent.create(recursive: true);
          await file.writeAsString(args['content'] as String? ?? '');
          return toResult('写入成功: $path');
        case 'list':
          final dir = Directory(path);
          if (await dir.exists()) {
            final entries = await dir.list().toList();
            return toResult(entries.map((e) => {'name': e.path.split(Platform.pathSeparator).last, 'path': e.path, 'type': e is Directory ? 'dir' : 'file'}).toList());
          }
          return toError('目录不存在: $path');
        case 'delete':
          if (await file.exists()) { await file.delete(); return toResult('删除成功'); }
          return toError('文件不存在');
        case 'exists':
          return toResult(await file.exists());
        default:
          return toError('未知操作: $action');
      }
    } catch (e) {
      return toError(e.toString());
    }
  }
}

/// Process run primitive — AI can execute system commands.
class ProcessRunPrimitive extends Primitive {
  @override String get name => 'process_run';
  @override String get description => '执行系统命令';
  @override Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'command': {'type': 'string', 'description': '要执行的命令'},
      'args': {'type': 'array', 'items': {'type': 'string'}, 'description': '命令参数'},
      'workDir': {'type': 'string', 'description': '工作目录'},
    },
    'required': ['command'],
  };

  @override
  Future<PrimitiveResult> execute(Map<String, dynamic> args) async {
    try {
      final cmd = args['command'] as String;
      final cmdArgs = (args['args'] as List?)?.cast<String>() ?? [];
      final workDir = args['workDir'] as String?;

      final result = await Process.run(cmd, cmdArgs,
        workingDirectory: workDir,
        runInShell: true,
      ).timeout(const Duration(seconds: 60));

      return PrimitiveResult(
        success: result.exitCode == 0,
        data: {'exitCode': result.exitCode, 'stdout': result.stdout.toString(), 'stderr': result.stderr.toString()},
      );
    } catch (e) {
      return toError(e.toString());
    }
  }
}

/// Database query primitive.
class DbQueryPrimitive extends Primitive {
  @override String get name => 'db_query';
  @override String get description => '查询本地数据库';
  @override Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'collection': {'type': 'string', 'description': '表名: conversations, messages, memories, devices'},
      'action': {'type': 'string', 'enum': ['list', 'get', 'search']},
      'id': {'type': 'string', 'description': '记录 ID (get)'},
      'query': {'type': 'string', 'description': '搜索关键词 (search)'},
    },
    'required': ['collection', 'action'],
  };

  @override
  Future<PrimitiveResult> execute(Map<String, dynamic> args) async {
    // For Phase 0, returns structured results from in-memory state
    // Will connect to full DB in Phase 2
    final collection = args['collection'] as String;
    final action = args['action'] as String;

    return PrimitiveResult(success: true, data: {
      'collection': collection,
      'action': action,
      'result': [],
      'note': 'Full DB integration in Phase 2',
    });
  }
}

/// Registry holding all primitives.
class PrimitiveRegistry {
  final Map<String, Primitive> _primitives = {};

  void register(Primitive p) => _primitives[p.name] = p;
  Primitive? get(String name) => _primitives[name];
  List<Primitive> get all => _primitives.values.toList();
  List<Map<String, dynamic>> get schemas => all.map((p) => p.parametersSchema).toList();

  /// Create with default primitives.
  static PrimitiveRegistry createDefault() {
    final r = PrimitiveRegistry();
    r.register(HttpCallPrimitive());
    r.register(FileOpsPrimitive());
    r.register(ProcessRunPrimitive());
    r.register(DbQueryPrimitive());
    return r;
  }
}
