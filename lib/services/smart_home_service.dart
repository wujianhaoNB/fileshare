import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/logger/app_logger.dart';
import '../data/models/smart_home_device.dart';

/// Manages IoT devices via MQTT and HomeAssistant REST API.
class SmartHomeService {
  final AppLogger _logger = AppLogger();
  final _devices = <String, SmartHomeDevice>{};
  final _controller = StreamController<List<SmartHomeDevice>>.broadcast();

  String? _haUrl;
  String? _haToken;

  Stream<List<SmartHomeDevice>> get devices => _controller.stream;
  List<SmartHomeDevice> get allDevices => _devices.values.toList();

  void configureHomeAssistant({required String url, required String token}) {
    _haUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    _haToken = token;
  }

  /// Discover devices from HomeAssistant.
  Future<List<SmartHomeDevice>> discoverFromHA() async {
    if (_haUrl == null || _haToken == null) return [];
    try {
      final resp = await http.get(
        Uri.parse('$_haUrl/api/states'),
        headers: {'Authorization': 'Bearer $_haToken', 'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final states = jsonDecode(resp.body) as List;
        for (final s in states) {
          final entityId = s['entity_id'] as String;
          final domain = entityId.split('.').first;
          if (['light', 'switch', 'climate', 'sensor', 'lock', 'cover', 'media_player', 'fan'].contains(domain)) {
            final device = SmartHomeDevice.fromHA(s);
            _devices[device.id] = device;
          }
        }
        _controller.add(allDevices);
        _logger.info('Discovered ${_devices.length} devices from HomeAssistant');
      }
    } catch (e) {
      _logger.error('HA discovery failed', e);
    }
    return allDevices;
  }

  /// Control a device via HomeAssistant REST API.
  Future<Map<String, dynamic>> controlDevice(SmartHomeDevice device, SmartHomeAction action) async {
    if (_haUrl == null || _haToken == null) {
      return {'success': false, 'error': 'HomeAssistant not configured'};
    }

    try {
      final domain = device.id.split('.').first;
      final service = action.haService;
      final data = <String, dynamic>{'entity_id': device.id};

      // Add action-specific data
      if (action.brightness != null) data['brightness_pct'] = action.brightness;
      if (action.temperature != null) data['temperature'] = action.temperature;
      if (action.colorHex != null) {
        final hex = action.colorHex!.replaceFirst('#', '');
        data['rgb_color'] = [int.parse(hex.substring(0,2), radix:16), int.parse(hex.substring(2,4), radix:16), int.parse(hex.substring(4,6), radix:16)];
      }

      final resp = await http.post(
        Uri.parse('$_haUrl/api/services/$domain/$service'),
        headers: {'Authorization': 'Bearer $_haToken', 'Content-Type': 'application/json'},
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 10));

      final result = {'success': resp.statusCode == 200, 'status': resp.statusCode};
      if (resp.statusCode == 200) {
        // Update device state
        device.state['state'] = action.state ?? (action.onOff != null ? (action.onOff! ? 'on' : 'off') : device.state['state']);
        _controller.add(allDevices);
      }
      return result;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Scan MQTT topics for devices (stub — full MQTT in future).
  Future<void> scanMqtt({String? broker, int port = 1883}) async {
    _logger.info('MQTT scanning configured for $broker:$port (full MQTT support in future update)');
  }

  Future<void> stop() async {
    await _controller.close();
  }
}

/// Represents a smart home action.
class SmartHomeAction {
  final String? state; // 'on', 'off', 'toggle'
  final bool? onOff;
  final int? brightness;
  final double? temperature;
  final String? colorHex;
  final String? scene;

  const SmartHomeAction({this.state, this.onOff, this.brightness, this.temperature, this.colorHex, this.scene});

  String get haService {
    if (state == 'toggle') return 'toggle';
    if (onOff == true) return 'turn_on';
    if (onOff == false) return 'turn_off';
    if (scene != null) return 'turn_on';
    return state == 'on' ? 'turn_on' : 'turn_off';
  }
}
