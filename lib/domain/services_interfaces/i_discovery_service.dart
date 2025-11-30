class SessionSummary {
  const SessionSummary({
    required this.id,
    required this.name,
    required this.hostName,
    required this.ip,
    required this.port,
  });

  final String id;
  final String name;
  final String hostName;
  final String ip;
  final int port;
}

abstract class IDiscoveryService {
  Stream<List<SessionSummary>> get sessions$;
  Future<void> startAnnouncing(SessionSummary summary);
  Future<void> stopAnnouncing(String sessionId);
  Future<void> startListening();
  Future<void> stopListening();
}

