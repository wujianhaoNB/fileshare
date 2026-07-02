/// Represents a smart home / IoT device.
class SmartHomeDevice {
  final String id; // entity_id in HomeAssistant
  final String name;
  final String type; // light, switch, climate, sensor, lock, cover, media_player, fan
  final String protocol; // mqtt, homeassistant, tuya, matter
  final Map<String, dynamic> state;
  bool isOnline;
  DateTime? lastSeen;
  final DateTime createdAt;

  SmartHomeDevice({
    required this.id, required this.name, required this.type,
    this.protocol = 'homeassistant',
    Map<String, dynamic>? state, this.isOnline = true, this.lastSeen,
    DateTime? createdAt,
  }) : state = state ?? <String, dynamic>{},
       createdAt = createdAt ?? DateTime.now();

  bool get isOn => state['state'] == 'on';
  String get currentState => state['state']?.toString() ?? 'unknown';
  Map<String, dynamic>? get attributes => state['attributes'] as Map<String, dynamic>?;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'type': type, 'protocol': protocol, 'state': state, 'is_online': isOnline};

  factory SmartHomeDevice.fromHA(Map<String, dynamic> haState) {
    final entityId = haState['entity_id'] as String;
    return SmartHomeDevice(
      id: entityId,
      name: (haState['attributes']?['friendly_name'] as String?) ?? entityId,
      type: entityId.split('.').first,
      protocol: 'homeassistant',
      state: haState,
      isOnline: haState['state'] != 'unavailable',
    );
  }
}
