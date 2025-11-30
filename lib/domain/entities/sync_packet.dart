class SyncPacket {
  const SyncPacket({
    required this.sessionId,
    required this.trackId,
    required this.position,
    required this.networkTime,
    required this.sequence,
  });

  final String sessionId;
  final String trackId;
  final Duration position;
  final int networkTime;
  final int sequence;
}

