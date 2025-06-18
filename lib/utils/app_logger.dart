import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode

// Top-level logger instance
final appLogger = Logger('NCDC_CCMS_App');

void setupLogging() {
  Logger.root.level = kDebugMode ? Level.ALL : Level.INFO; // Configure log levels
  Logger.root.onRecord.listen((record) {
    // Simple console output, can be customized further (e.g., write to file)
    debugPrint('\${record.level.name}: \${record.time}: \${record.loggerName}: \${record.message}');
    if (record.error != null) {
      debugPrint('Error: \${record.error}');
    }
    if (record.stackTrace != null) {
      debugPrint('StackTrace: \${record.stackTrace}');
    }
  });
}
