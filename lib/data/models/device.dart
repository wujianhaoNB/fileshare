/// Represents a discovered or paired device on the network.
class Device {
  final String id;
  final String displayName;
  final String? publicKey;
  final String ip;
  final int port;
  final int trustLevel; // 0=discovered, 1=paired, 2=verified
  final bool hasBluetooth;
  final String? appVersion;
  final DateTime? lastSeenAt;
  final bool isOnline;

  const Device({
    required this.id,
    required this.displayName,
    this.publicKey,
    required this.ip,
    this.port = 8080,
    this.trustLevel = 0,
    this.hasBluetooth = false,
    this.appVersion,
    this.lastSeenAt,
    this.isOnline = true,
  });

  bool get isPaired => trustLevel >= 1;
  bool get isVerified => trustLevel >= 2;

  Device copyWith({
    String? id,
    String? displayName,
    String? publicKey,
    String? ip,
    int? port,
    int? trustLevel,
    bool? hasBluetooth,
    String? appVersion,
    DateTime? lastSeenAt,
    bool? isOnline,
  }) {
    return Device(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      publicKey: publicKey ?? this.publicKey,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      trustLevel: trustLevel ?? this.trustLevel,
      hasBluetooth: hasBluetooth ?? this.hasBluetooth,
      appVersion: appVersion ?? this.appVersion,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  /// Create from mDNS TXT record data.
  factory Device.fromMdns({
    required String ip,
    required int port,
    required String name,
    required Map<String, String> txtRecords,
  }) {
    return Device(
      id: 'mdns_${ip}_$port',
      displayName: name,
      ip: ip,
      port: port,
      trustLevel: 0,
      hasBluetooth: txtRecords['bt'] == 'true',
      appVersion: txtRecords['v'],
      isOnline: true,
      lastSeenAt: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Device && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
