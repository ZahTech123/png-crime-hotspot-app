import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'logger.dart';

/// Debug utility class for monitoring and troubleshooting camera operations
class MapDebugHelper {
  static bool _debugEnabled = false;
  static final List<CameraOperation> _operationHistory = [];
  static const int _maxHistorySize = 50;

  /// Enable or disable debug logging
  static void setDebugEnabled(bool enabled) {
    _debugEnabled = enabled;
    AppLogger.i('[MapDebugHelper] Debug logging ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Check if debug is enabled
  static bool get isDebugEnabled => _debugEnabled;

  /// Log a camera operation for debugging
  static void logCameraOperation({
    required String operationType,
    required List<mapbox.Position> coordinates,
    mapbox.CameraOptions? cameraOptions,
    BuildContext? context,
    String? additionalInfo,
    bool? isSuccess,
    String? errorMessage,
  }) {
    if (!_debugEnabled) return;

    final operation = CameraOperation(
      timestamp: DateTime.now(),
      operationType: operationType,
      coordinateCount: coordinates.length,
      coordinates: coordinates.take(3).toList(), // Store only first 3 for brevity
      cameraOptions: cameraOptions,
      hasContext: context != null,
      additionalInfo: additionalInfo,
      isSuccess: isSuccess,
      errorMessage: errorMessage,
    );

    _operationHistory.add(operation);
    
    // Keep history size manageable
    if (_operationHistory.length > _maxHistorySize) {
      _operationHistory.removeAt(0);
    }

    // Log the operation
    final message = '[CameraOp] $operationType: ${coordinates.length} coords, '
        'context: ${context != null}, ${additionalInfo ?? ''}';
    
    if (isSuccess == false && errorMessage != null) {
      AppLogger.e('$message - ERROR: $errorMessage');
    } else {
      AppLogger.d(message);
    }
  }

  /// Get operation history for debugging
  static List<CameraOperation> getOperationHistory() {
    return List.unmodifiable(_operationHistory);
  }

  /// Get recent failed operations
  static List<CameraOperation> getFailedOperations() {
    return _operationHistory
        .where((op) => op.isSuccess == false)
        .toList();
  }

  /// Clear operation history
  static void clearHistory() {
    _operationHistory.clear();
    AppLogger.i('[MapDebugHelper] Operation history cleared');
  }

  /// Generate debug report
  static String generateDebugReport() {
    final report = StringBuffer();
    report.writeln('=== MAP DEBUG REPORT ===');
    report.writeln('Generated: ${DateTime.now()}');
    report.writeln('Debug enabled: $_debugEnabled');
    report.writeln('Total operations: ${_operationHistory.length}');
    
    final failed = getFailedOperations();
    report.writeln('Failed operations: ${failed.length}');
    report.writeln('');

    if (_operationHistory.isNotEmpty) {
      report.writeln('RECENT OPERATIONS:');
      for (final op in _operationHistory.reversed.take(10)) {
        report.writeln('${op.timestamp}: ${op.operationType} '
            '(${op.coordinateCount} coords) - '
            '${op.isSuccess == null ? 'PENDING' : op.isSuccess! ? 'SUCCESS' : 'FAILED'}');
        if (op.errorMessage != null) {
          report.writeln('  Error: ${op.errorMessage}');
        }
      }
    }

    if (failed.isNotEmpty) {
      report.writeln('');
      report.writeln('FAILED OPERATIONS DETAIL:');
      for (final op in failed.reversed.take(5)) {
        report.writeln('${op.timestamp}: ${op.operationType}');
        report.writeln('  Coordinates: ${op.coordinateCount}');
        report.writeln('  Context: ${op.hasContext}');
        report.writeln('  Error: ${op.errorMessage}');
        if (op.additionalInfo != null) {
          report.writeln('  Info: ${op.additionalInfo}');
        }
        report.writeln('');
      }
    }

    return report.toString();
  }

  /// Validate camera state for debugging
  static CameraValidationResult validateCameraState({
    required List<mapbox.Position> coordinates,
    BuildContext? context,
    mapbox.CameraOptions? cameraOptions,
  }) {
    final issues = <String>[];
    final warnings = <String>[];

    // Check coordinates
    if (coordinates.isEmpty) {
      warnings.add('No coordinates provided - will use default view');
    } else {
      for (int i = 0; i < coordinates.length; i++) {
        final coord = coordinates[i];
        if (coord.lat < -90 || coord.lat > 90) {
          issues.add('Coordinate $i: Invalid latitude ${coord.lat}');
        }
        if (coord.lng < -180 || coord.lng > 180) {
          issues.add('Coordinate $i: Invalid longitude ${coord.lng}');
        }
        if (coord.lat.isNaN || coord.lng.isNaN) {
          issues.add('Coordinate $i: NaN values detected');
        }
      }
    }

    // Check context
    if (context == null) {
      warnings.add('Context not available - using fallback dimensions');
    }

    // Check camera options
    if (cameraOptions?.zoom != null) {
      final zoom = cameraOptions!.zoom!;
      if (zoom < 0 || zoom > 22) {
        issues.add('Invalid zoom level: $zoom (should be 0-22)');
      }
    }

    final isValid = issues.isEmpty;
    return CameraValidationResult(
      isValid: isValid,
      issues: issues,
      warnings: warnings,
      summary: isValid 
          ? 'Camera state is valid${warnings.isNotEmpty ? ' with ${warnings.length} warnings' : ''}'
          : '${issues.length} validation errors found',
    );
  }

  /// Log performance metrics
  static void logPerformanceMetrics({
    required String operation,
    required Duration duration,
    int? coordinateCount,
    double? finalZoom,
  }) {
    if (!_debugEnabled) return;

    AppLogger.d('[Performance] $operation: ${duration.inMilliseconds}ms, '
        'coords: $coordinateCount, zoom: $finalZoom');
  }
}

/// Represents a camera operation for debugging
class CameraOperation {
  final DateTime timestamp;
  final String operationType;
  final int coordinateCount;
  final List<mapbox.Position> coordinates;
  final mapbox.CameraOptions? cameraOptions;
  final bool hasContext;
  final String? additionalInfo;
  final bool? isSuccess;
  final String? errorMessage;

  const CameraOperation({
    required this.timestamp,
    required this.operationType,
    required this.coordinateCount,
    required this.coordinates,
    this.cameraOptions,
    required this.hasContext,
    this.additionalInfo,
    this.isSuccess,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'operationType': operationType,
      'coordinateCount': coordinateCount,
      'coordinates': coordinates.map((c) => [c.lng, c.lat]).toList(),
      'hasContext': hasContext,
      'additionalInfo': additionalInfo,
      'isSuccess': isSuccess,
      'errorMessage': errorMessage,
    };
  }
}

/// Camera validation result for debugging
class CameraValidationResult {
  final bool isValid;
  final List<String> issues;
  final List<String> warnings;
  final String summary;

  const CameraValidationResult({
    required this.isValid,
    required this.issues,
    required this.warnings,
    required this.summary,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Validation Result: $summary');
    
    if (issues.isNotEmpty) {
      buffer.writeln('Issues:');
      for (final issue in issues) {
        buffer.writeln('  - $issue');
      }
    }
    
    if (warnings.isNotEmpty) {
      buffer.writeln('Warnings:');
      for (final warning in warnings) {
        buffer.writeln('  - $warning');
      }
    }
    
    return buffer.toString();
  }
} 