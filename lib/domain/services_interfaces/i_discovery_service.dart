import '../entities/session_summary.dart';

abstract class IDiscoveryService {
  Stream<List<SessionSummary>> get sessions$;
  Future<void> startAnnouncing(SessionSummary summary);
  Future<void> stopAnnouncing(String sessionId);
  Future<void> startListening();
  Future<void> stopListening();
}
