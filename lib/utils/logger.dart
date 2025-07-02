import 'package:flutter/foundation.dart';

/// Application logger utility
/// Provides consistent logging across the application with appropriate levels
/// Uses built-in Flutter logging to avoid external dependencies
class AppLogger {
  static const String _prefix = '[NCDC-CCMS]';

  /// Debug level logging - only in debug mode
  static void d(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('$_prefix [DEBUG] $message');
      if (error != null) {
        debugPrint('$_prefix [DEBUG] Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('$_prefix [DEBUG] StackTrace: $stackTrace');
      }
    }
  }

  /// Info level logging
  static void i(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('$_prefix [INFO] $message');
      if (error != null) {
        debugPrint('$_prefix [INFO] Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('$_prefix [INFO] StackTrace: $stackTrace');
      }
    }
  }

  /// Warning level logging
  static void w(String message, [dynamic error, StackTrace? stackTrace]) {
    debugPrint('$_prefix [WARNING] $message');
    if (error != null) {
      debugPrint('$_prefix [WARNING] Error: $error');
    }
    if (stackTrace != null) {
      debugPrint('$_prefix [WARNING] StackTrace: $stackTrace');
    }
  }

  /// Error level logging
  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    debugPrint('$_prefix [ERROR] $message');
    if (error != null) {
      debugPrint('$_prefix [ERROR] Error: $error');
    }
    if (stackTrace != null) {
      debugPrint('$_prefix [ERROR] StackTrace: $stackTrace');
    }
  }

  /// Fatal level logging
  static void f(String message, [dynamic error, StackTrace? stackTrace]) {
    debugPrint('$_prefix [FATAL] $message');
    if (error != null) {
      debugPrint('$_prefix [FATAL] Error: $error');
    }
    if (stackTrace != null) {
      debugPrint('$_prefix [FATAL] StackTrace: $stackTrace');
    }
  }
} 