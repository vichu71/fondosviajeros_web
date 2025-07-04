// lib/utils/logger.dart

import 'package:flutter/foundation.dart';

enum LogType { info, success, warning, error, api }

const bool isLoggingEnabled = true; // Cambia a false en producción

void log(String message, {LogType type = LogType.info}) {
  if (!isLoggingEnabled) return;

  final now = DateTime.now().toIso8601String().substring(11, 19); // HH:mm:ss

  final String tag = switch (type) {
    LogType.info => 'INFO',
    LogType.success => 'OK',
    LogType.warning => 'WARN',
    LogType.error => 'ERROR',
    LogType.api => 'API',
  };

  final String emoji = switch (type) {
    LogType.info => 'ℹ️',
    LogType.success => '✅',
    LogType.warning => '⚠️',
    LogType.error => '❌',
    LogType.api => '📡',
  };

  debugPrint('$emoji [$now] [$tag] $message');
}
