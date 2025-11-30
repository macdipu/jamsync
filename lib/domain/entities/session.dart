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
}

