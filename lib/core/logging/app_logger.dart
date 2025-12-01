import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Log levels
enum LogLevel { info, warn, error }

class AppLogger {
  AppLogger({bool useColors = true})
      : _useColors = useColors && !kIsWeb,
        _logFile = File('${Directory.systemTemp.path}/jamSyncLogs.txt');

  final File _logFile;
  final bool _useColors;

  // ANSI Colors (for terminals only)
  static const _reset = '\x1B[0m';
  static const _blue = '\x1B[34m';
  static const _yellow = '\x1B[33m';
  static const _red = '\x1B[31m';

  // ----------------------------- Public API -------------------------------- //

  void info(String message) {
    _log(LogLevel.info, message);
  }

  void warn(String message) {
    _log(LogLevel.warn, message);
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    final msg = [
      message,
      if (error != null) 'Error: $error',
      if (stackTrace != null) 'StackTrace:\n$stackTrace',
    ].join('\n');

    _log(LogLevel.error, msg);
  }

  Future<List<String>> loadEntries() async {
    if (!await _logFile.exists()) return const [];
    return _logFile.readAsLines();
  }

  // ---------------------------- Internal Logic ----------------------------- //

  void _log(LogLevel level, String message) {
    final formatted = _format(level, message);

    // Print colored or plain
    _printToConsole(level, formatted);

    // Write to file in background
    scheduleMicrotask(() => _append(formatted));
  }

  String _format(LogLevel level, String message) {
    final ts = DateTime.now().toIso8601String();
    final tag = level.name.toUpperCase();
    return "[$ts] $tag: $message";
  }

  void _printToConsole(LogLevel level, String line) {
    if (!_useColors) {
      print(line);
      return;
    }

    switch (level) {
      case LogLevel.info:
        print("$_blue$line$_reset");
        break;
      case LogLevel.warn:
        print("$_yellow$line$_reset");
        break;
      case LogLevel.error:
        print("$_red$line$_reset");
        break;
    }
  }

  Future<void> _append(String message) async {
    try {
      await _logFile.writeAsString('$message\n', mode: FileMode.append);
    } catch (e, st) {
      // Fallback logging if file write fails
      // ignore: avoid_print
      print("LOGGER FILE WRITE ERROR: $e\n$st");
    }
  }
}
