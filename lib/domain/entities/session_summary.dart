import 'device.dart';

class SessionSummary {
  const SessionSummary({
    required this.id,
    required this.name,
    required this.hostName,
    required this.ip,
    required this.port,
    this.host,
  });

  final String id;
  final String name;
  final String hostName;
  final String ip;
  final int port;
  final Device? host;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'hostName': hostName,
      'ip': ip,
      'port': port,
      'host': host?.toJson(),
    };
  }

  factory SessionSummary.fromJson(Map<String, dynamic> json) {
    return SessionSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      hostName: json['hostName'] as String,
      ip: json['ip'] as String,
      port: json['port'] as int,
      host: json['host'] == null ? null : Device.fromJson(json['host'] as Map<String, dynamic>),
    );
  }
}
