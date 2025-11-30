import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../../domain/services_interfaces/i_local_storage_service.dart';
import '../../domain/value_objects/session_config.dart';

class LocalSettingsStorage implements ILocalStorageService {
  LocalSettingsStorage({Directory? directory}) : _directoryFuture = directory != null ? Future.value(directory) : getApplicationSupportDirectory();

  final Future<Directory> _directoryFuture;

  Future<File> get _configFile async {
    final dir = await _directoryFuture;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}/session_config.json');
  }

  @override
  Future<void> saveSession(SessionResumeData data) async {
    final file = await _configFile;
    await file.writeAsString(jsonEncode(data.toJson()));
  }

  @override
  Future<SessionResumeData?> loadSession() async {
    final file = await _configFile;
    if (!await file.exists()) {
      return null;
    }
    final content = await file.readAsString();
    return SessionResumeData.fromJson(jsonDecode(content) as Map<String, dynamic>);
  }
}
