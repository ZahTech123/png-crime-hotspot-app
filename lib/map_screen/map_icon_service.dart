import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../utils/logger.dart';

/// Service for managing and caching map icons with pre-loaded size variants
/// This eliminates repeated asset loading and provides optimized icon management
class MapIconService {
  static MapIconService? _instance;
  static MapIconService get instance => _instance ??= MapIconService._();
  
  MapIconService._();

  // Cache for the original icon data
  Uint8List? _originalIconData;
  
  // Cache for pre-generated icon variants at different sizes
  final Map<double, Uint8List> _iconVariants = {};
  
  // Pre-defined size levels for discrete sizing (more efficient than continuous)
  static const List<double> _predefinedSizes = [0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.2];
  
  bool _isInitialized = false;
  bool _isDisposed = false;

  /// Initialize the service and pre-load icon variants
  Future<void> initialize() async {
    if (_isInitialized || _isDisposed) return;
    
    try {
      AppLogger.i('[MapIconService] Initializing icon cache...');
      
      // Load the original icon data once
      final ByteData bytes = await rootBundle.load('assets/map-point.png');
      _originalIconData = bytes.buffer.asUint8List();
      
      // Pre-generate size variants for efficient scaling
      await _generateIconVariants();
      
      _isInitialized = true;
      AppLogger.i('[MapIconService] Icon cache initialized with ${_iconVariants.length} size variants');
      
    } catch (e) {
      AppLogger.e('[MapIconService] Failed to initialize icon cache', e);
      rethrow;
    }
  }

  /// Get cached icon data for the closest pre-defined size
  Uint8List getIconForSize(double requestedSize) {
    if (!_isInitialized) {
      throw StateError('MapIconService not initialized. Call initialize() first.');
    }
    
    if (_originalIconData == null) {
      throw StateError('Original icon data not loaded');
    }

    // Find the closest pre-defined size
    final closestSize = _findClosestSize(requestedSize);
    
    // Return the variant or original data
    return _iconVariants[closestSize] ?? _originalIconData!;
  }

  /// Get the original icon data (size 1.0)
  Uint8List get originalIcon {
    if (!_isInitialized || _originalIconData == null) {
      throw StateError('MapIconService not initialized');
    }
    return _originalIconData!;
  }

  /// Find the closest pre-defined size to the requested size
  double _findClosestSize(double requestedSize) {
    if (requestedSize <= _predefinedSizes.first) {
      return _predefinedSizes.first;
    }
    if (requestedSize >= _predefinedSizes.last) {
      return _predefinedSizes.last;
    }
    
    double closest = _predefinedSizes.first;
    double minDiff = (requestedSize - closest).abs();
    
    for (final size in _predefinedSizes) {
      final diff = (requestedSize - size).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = size;
      }
    }
    
    return closest;
  }

  /// Pre-generate icon variants for efficient access
  Future<void> _generateIconVariants() async {
    if (_originalIconData == null) return;
    
    // For now, we'll store the original data for each size
    // In a more advanced implementation, you could resize the actual image
    // but since Mapbox handles the sizing, we just need the same data
    for (final size in _predefinedSizes) {
      _iconVariants[size] = _originalIconData!;
    }
    
    AppLogger.d('[MapIconService] Generated ${_iconVariants.length} icon variants');
  }

  /// Get size level for zoom-based icon sizing with discrete steps
  double getSizeForZoom(double zoom) {
    const double minZoom = 10.0;
    const double maxZoom = 18.0;
    
    if (zoom <= minZoom) return _predefinedSizes.first;
    if (zoom >= maxZoom) return _predefinedSizes.last;
    
    // Calculate size using linear interpolation
    final double zoomRatio = (zoom - minZoom) / (maxZoom - minZoom);
    final double continuousSize = _predefinedSizes.first + 
        ((_predefinedSizes.last - _predefinedSizes.first) * zoomRatio);
    
    // Return the closest discrete size
    return _findClosestSize(continuousSize);
  }

  /// Check if size change is significant enough to warrant an update
  bool shouldUpdateSize(double currentSize, double newSize, {double threshold = 0.15}) {
    return (newSize - currentSize).abs() >= threshold;
  }

  /// Get batch update groups for efficient marker updates
  Map<double, List<T>> groupMarkersBySize<T>(
    List<T> markers, 
    double Function(T) getCurrentSize,
    double newSize
  ) {
    final Map<double, List<T>> groups = {};
    
    for (final marker in markers) {
      final currentSize = getCurrentSize(marker);
      
      if (shouldUpdateSize(currentSize, newSize)) {
        groups.putIfAbsent(newSize, () => []).add(marker);
      }
    }
    
    return groups;
  }

  /// Get cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    return {
      'isInitialized': _isInitialized,
      'originalIconSize': _originalIconData?.length ?? 0,
      'variantCount': _iconVariants.length,
      'predefinedSizes': _predefinedSizes,
      'memoryUsage': _calculateMemoryUsage(),
    };
  }

  int _calculateMemoryUsage() {
    int total = _originalIconData?.length ?? 0;
    for (final variant in _iconVariants.values) {
      total += variant.length;
    }
    return total;
  }

  /// Dispose resources and clear cache
  void dispose() {
    if (_isDisposed) return;
    
    _originalIconData = null;
    _iconVariants.clear();
    _isInitialized = false;
    _isDisposed = true;
    
    AppLogger.i('[MapIconService] Icon cache disposed');
  }

  /// Reset the singleton instance (for testing)
  static void resetInstance() {
    _instance?.dispose();
    _instance = null;
  }
}

/// Result class for batch marker update operations
class BatchUpdateResult {
  final int totalMarkers;
  final int updatedMarkers;
  final Duration processingTime;
  final Map<double, int> sizeGroups;

  BatchUpdateResult({
    required this.totalMarkers,
    required this.updatedMarkers,
    required this.processingTime,
    required this.sizeGroups,
  });

  @override
  String toString() {
    return 'BatchUpdateResult(total: $totalMarkers, updated: $updatedMarkers, '
           'time: ${processingTime.inMilliseconds}ms, groups: $sizeGroups)';
  }
} 