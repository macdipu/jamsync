import '../value_objects/session_config.dart';

abstract class ILocalStorageService {
  Future<void> saveSession(SessionResumeData data);
  Future<SessionResumeData?> loadSession();
}

