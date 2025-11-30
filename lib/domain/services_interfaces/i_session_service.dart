import '../entities/device.dart';
import '../entities/session.dart';
import '../entities/session_summary.dart';

abstract class ISessionService {
  Future<Session> createSession({required String name, required Device admin});
  Future<void> announceSession(Session session);
  Future<void> stopSession(String sessionId);
  Stream<List<Session>> get sessions$;
  Future<Session> joinSession(SessionSummary summary, Device localDevice);
}
