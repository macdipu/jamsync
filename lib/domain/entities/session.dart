import 'device.dart';
import 'track.dart';

class Session {
  const Session({
    required this.id,
    required this.name,
    required this.admin,
    required this.members,
    required this.queue,
    this.player,
  });

  final String id;
  final String name;
  final Device admin;
  final Device? player;
  final List<Device> members;
  final List<Track> queue;

  Session copyWith({
    String? id,
    String? name,
    Device? admin,
    Device? player,
    List<Device>? members,
    List<Track>? queue,
  }) {
    return Session(
      id: id ?? this.id,
      name: name ?? this.name,
      admin: admin ?? this.admin,
      player: player ?? this.player,
      members: members ?? this.members,
      queue: queue ?? this.queue,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'admin': admin.toJson(),
      'player': player?.toJson(),
      'members': members.map((device) => device.toJson()).toList(),
      'queue': queue.map((track) => track.toJson()).toList(),
    };
  }

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] as String,
      name: json['name'] as String,
      admin: Device.fromJson(json['admin'] as Map<String, dynamic>),
      player: json['player'] == null
          ? null
          : Device.fromJson(json['player'] as Map<String, dynamic>),
      members: (json['members'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(Device.fromJson)
          .toList(),
      queue: (json['queue'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(Track.fromJson)
          .toList(),
    );
  }
}
