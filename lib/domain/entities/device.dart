enum DeviceRole { admin, player, speaker }

class Device {
  const Device({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    required this.role,
    this.isLocal = false,
  });

  final String id;
  final String name;
  final String ip;
  final int port;
  final DeviceRole role;
  final bool isLocal;

  Device copyWith({
    String? id,
    String? name,
    String? ip,
    int? port,
    DeviceRole? role,
    bool? isLocal,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      role: role ?? this.role,
      isLocal: isLocal ?? this.isLocal,
    );
  }
}

