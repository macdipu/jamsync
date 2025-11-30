import 'dart:convert';
import 'dart:io';

import '../../domain/services_interfaces/i_local_storage_service.dart';
import '../../domain/value_objects/session_config.dart';

class LocalSettingsStorage implements ILocalStorageService {
  LocalSettingsStorage({Directory? directory})
      : _directory = directory ?? Directory('${Directory.systemTemp.path}/jamSyncSettings');

  final Directory _directory;

  File get _configFile => File('${_directory.path}/session_config.json');

  @override
  Future<void> saveSession(SessionResumeData data) async {
    await _configFile.writeAsString(jsonEncode(data.toJson()));
  }

  @override
  Future<SessionResumeData?> loadSession() async {
    if (!await _configFile.exists()) {
      return null;
    }
    final content = await _configFile.readAsString();
    return SessionResumeData.fromJson(jsonDecode(content) as Map<String, dynamic>);
  }
}
