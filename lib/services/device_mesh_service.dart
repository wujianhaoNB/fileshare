import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/logger/app_logger.dart';
import '../data/models/device.dart';
import '../network/discovery/composite_discovery.dart';

/// Capability of a device in the mesh.
class DeviceCapability {
  final String deviceId;
  final String deviceName;
  final String deviceType; // android_phone, iphone, windows_pc, etc.
  final String ip;
  final int port;
  final List<String> capabilities;
  final bool isOnline;
  final DateTime lastSeen;

  const DeviceCapability({
    required this.deviceId, required this.deviceName, required this.deviceType,
    required this.ip, required this.port, required this.capabilities,
    this.isOnline = true, required this.lastSeen,
  });

  bool hasCapability(String cap) => capabilities.contains(cap);

  Map<String, dynamic> toJson() => {
    'device_id': deviceId, 'device_name': deviceName, 'device_type': deviceType,
    'ip': ip, 'port': port, 'capabilities': capabilities,
    'is_online': isOnline, 'last_seen': lastSeen.toIso8601String(),
  };
}

/// Remote task definition.
class RemoteTask {
  final String taskId;
  final String action;
  final Map<String, dynamic> args;
  final String originDevice;
  final String priority;
  final String callbackType;

  const RemoteTask({
    required this.taskId, required this.action, required this.args,
    required this.originDevice, this.priority = 'normal', this.callbackType = 'result_only',
  });

  Map<String, dynamic> toJson() => {
    'task_id': taskId, 'action': action, 'args': args,
    'origin_device': originDevice, 'priority': priority, 'callback_type': callbackType,
  };
}

/// Result of a remote task execution.
class RemoteTaskResult {
  final String taskId;
  final String status;
  final Map<String, dynamic>? result;
  final String? output;

  const RemoteTaskResult({required this.taskId, required this.status, this.result, this.output});
  factory RemoteTaskResult.fromJson(Map<String, dynamic> json) => RemoteTaskResult(
    taskId: json['task_id'] as String, status: json['status'] as String,
    result: json['result'] as Map<String, dynamic>?, output: json['output'] as String?,
  );
}

/// Manages the cross-device AI mesh — discovery, capability exchange, and remote task delegation.
class DeviceMeshService {
  final AppLogger _logger = AppLogger();
  final CompositeDiscovery _discovery = CompositeDiscovery();

  final _capabilities = <String, DeviceCapability>{};
  final _controller = StreamController<List<DeviceCapability>>.broadcast();

  String _deviceName = 'AI Assistant';
  String _deviceType = 'windows_pc';
  List<String> _localCapabilities = ['ai_chat', 'file_transfer', 'shell_exec'];

  Stream<List<DeviceCapability>> get devices => _controller.stream;
  List<DeviceCapability> get knownDevices => _capabilities.values.toList();
  List<String> get localCapabilities => List.unmodifiable(_localCapabilities);

  /// Set the local device info and capabilities.
  void configure({
    required String deviceName, required String deviceType, required List<String> capabilities,
  }) {
    _deviceName = deviceName;
    _deviceType = deviceType;
    _localCapabilities = capabilities;
  }

  /// Add a capability to this device.
  void addCapability(String cap) {
    if (!_localCapabilities.contains(cap)) {
      _localCapabilities.add(cap);
      _logger.info('New capability added: $cap');
    }
  }

  /// Start mesh discovery.
  Future<void> start({String? ownIp}) async {
    _logger.info('Starting device mesh discovery');
    await _discovery.start(deviceName: _deviceName, port: 8080);

    _discovery.devices.listen((device) {
      if (device.ip == ownIp) return;
      _updateDevice(device);
    });
  }

  void _updateDevice(Device device) {
    final key = '${device.ip}:${device.port}';
    // Try to fetch capabilities from the device
    _fetchCapabilities(device.ip, device.port).then((caps) {
      final dc = DeviceCapability(
        deviceId: device.id, deviceName: device.displayName,
        deviceType: 'unknown', ip: device.ip, port: device.port,
        capabilities: caps, isOnline: true, lastSeen: DateTime.now(),
      );
      _capabilities[key] = dc;
      _controller.add(knownDevices);
    }).catchError((_) {
      // Fallback: device is there but we can't get capabilities
      if (!_capabilities.containsKey(key)) {
        _capabilities[key] = DeviceCapability(
          deviceId: device.id, deviceName: device.displayName,
          deviceType: 'unknown', ip: device.ip, port: device.port,
          capabilities: ['file_transfer'], isOnline: true, lastSeen: DateTime.now(),
        );
        _controller.add(knownDevices);
      }
    });
  }

  /// Fetch capabilities from a remote device's /discover endpoint.
  Future<List<String>> _fetchCapabilities(String ip, int port) async {
    try {
      final resp = await http.get(Uri.parse('http://$ip:$port/discover')).timeout(const Duration(seconds: 3));
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        final caps = json['capabilities'] as List?;
        return caps?.cast<String>() ?? ['file_transfer'];
      }
    } catch (_) {}
    return ['file_transfer'];
  }

  /// Delegate a task to a remote device.
  Future<RemoteTaskResult> delegateTask(DeviceCapability target, RemoteTask task) async {
    try {
      final resp = await http.post(
        Uri.parse('http://${target.ip}:${target.port}/execute'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(task.toJson()),
      ).timeout(const Duration(seconds: 30));

      if (resp.statusCode == 200) {
        return RemoteTaskResult.fromJson(jsonDecode(resp.body));
      }
      return RemoteTaskResult(taskId: task.taskId, status: 'failed', output: 'HTTP ${resp.statusCode}');
    } catch (e) {
      return RemoteTaskResult(taskId: task.taskId, status: 'failed', output: e.toString());
    }
  }

  /// Find a device by capability.
  DeviceCapability? findDeviceWithCapability(String capability) {
    try {
      return _capabilities.values.firstWhere((d) => d.hasCapability(capability) && d.isOnline);
    } catch (_) {
      return null;
    }
  }

  Future<void> stop() async {
    await _discovery.stop();
    await _controller.close();
  }
}
