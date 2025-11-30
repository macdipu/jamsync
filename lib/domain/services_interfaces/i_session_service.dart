import '../entities/device.dart';
import '../entities/session.dart';
import 'i_discovery_service.dart';

abstract class ISessionService {
  Future<Session> createSession({required String name, required Device admin});
  Future<void> announceSession(Session session);
  Future<void> stopSession(String sessionId);
  Stream<List<Session>> get sessions$;
  Future<void> joinSession(SessionSummary summary);
}
