import '../entities/device.dart';
import '../entities/session.dart';

abstract class IRoleService {
  Future<Session> assignPlayer(Session session, Device newPlayer);
  Future<Session> assignSpeaker(Session session, Device speaker);
}

