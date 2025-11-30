import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger()
      : _logFile = File('${Directory.systemTemp.path}/jamSyncLogs.txt');

  final File _logFile;

  void info(String message) {
    final line = 'INFO: $message';
    // ignore: avoid_print
    print(line);
    scheduleMicrotask(() => _append(line));
  }

  void warn(String message) {
    if (kDebugMode) {
      debugPrint('WARN: $message');
    }
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    final line = 'ERROR: $message';
    // ignore: avoid_print
    print(line);
    if (error != null) {
      // ignore: avoid_print
      print(error);
    }
    if (stackTrace != null) {
      // ignore: avoid_print
      print(stackTrace);
    }
    scheduleMicrotask(() => _append([line, error?.toString(), stackTrace?.toString()].whereType<String>().join('\n')));
  }

  Future<void> _append(String message) async {
    final timestamp = DateTime.now().toIso8601String();
    await _logFile.writeAsString('[$timestamp] $message\n', mode: FileMode.append);
  }

  Future<List<String>> loadEntries() async {
    if (!await _logFile.exists()) {
      return const [];
    }
    return _logFile.readAsLines();
  }
}
