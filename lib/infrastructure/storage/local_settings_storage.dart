import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../../core/logging/app_logger.dart';
import '../../domain/services_interfaces/i_local_storage_service.dart';
import '../../domain/value_objects/session_config.dart';

class LocalSettingsStorage implements ILocalStorageService {
  LocalSettingsStorage({Directory? directory, AppLogger? logger})
      : _directoryFuture = directory != null ? Future.value(directory) : getApplicationSupportDirectory(),
        _logger = logger;

  final Future<Directory> _directoryFuture;
  final AppLogger? _logger;

  Future<File> get _configFile async {
    final dir = await _directoryFuture;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}/session_config.json');
  }

  @override
  Future<void> saveSession(SessionResumeData data) async {
    try {
      final file = await _configFile;
      await file.writeAsString(jsonEncode(data.toJson()));
      _logger?.info('Session persisted to ${file.path}');
    } catch (error, stack) {
      _logger?.error('Failed to save session resume data: $error', error, stack);
    }
  }

  @override
  Future<SessionResumeData?> loadSession() async {
    try {
      final file = await _configFile;
      if (!await file.exists()) {
        _logger?.info('No cached session file found');
        return null;
      }
      final content = await file.readAsString();
      final data = SessionResumeData.fromJson(jsonDecode(content) as Map<String, dynamic>);
      _logger?.info('Loaded cached session ${data.summary.id}');
      return data;
    } catch (error, stack) {
      _logger?.error('Failed to load session resume data: $error', error, stack);
      return null;
    }
  }
}
