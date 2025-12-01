enum MessageType {
  announceSession,
  joinRequest,
  joinAccept,
  joinReject,
  roleChange,
  playbackCommand,
  queueUpdate,
  syncTick,
  ping,
  pong,
  stateRequest,
  text,
}

class ControlMessage {
  const ControlMessage({
    required this.type,
    required this.payload,
  });

  final MessageType type;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'payload': payload,
    };
  }

  factory ControlMessage.fromJson(Map<String, dynamic> json) {
    return ControlMessage(
      type: MessageType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => MessageType.text,
      ),
      payload: Map<String, dynamic>.from(json['payload'] ?? <String, dynamic>{}),
    );
  }
}
