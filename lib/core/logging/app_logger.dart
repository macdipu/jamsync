import 'package:flutter/foundation.dart';

class AppLogger {
  void info(String message) {
    if (kDebugMode) {
      debugPrint('INFO: $message');
    }
  }

  void warn(String message) {
    if (kDebugMode) {
      debugPrint('WARN: $message');
    }
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('ERROR: $message');
      if (error != null) {
        debugPrint('  error: $error');
      }
      if (stackTrace != null) {
        debugPrint(stackTrace.toString());
      }
    }
  }
}

