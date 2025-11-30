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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ip': ip,
      'port': port,
      'role': role.name,
      'isLocal': isLocal,
    };
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      name: json['name'] as String,
      ip: json['ip'] as String,
      port: json['port'] as int,
      role: DeviceRole.values.firstWhere(
        (role) => role.name == json['role'],
        orElse: () => DeviceRole.speaker,
      ),
      isLocal: json['isLocal'] as bool? ?? false,
    );
  }
}
