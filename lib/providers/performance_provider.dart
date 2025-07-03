import 'package:flutter/foundation.dart';
import 'package:ncdc_ccms_app/utils/logger.dart';
import 'dart:async';
import 'dart:io'; // Add for Platform detection

/// Performance-focused provider that manages application state with granular updates
/// This prevents unnecessary widget rebuilds and improves UI responsiveness
class PerformanceProvider with ChangeNotifier {
  
  // Performance metrics
  DateTime? _lastFrameTime;
  int _frameCount = 0;
  double _averageFps = 60.0;
  final List<Duration> _frameTimes = [];
  static const int _frameHistoryLimit = 60; // Keep last 60 frame times
  
  // Loading states - granular to prevent full rebuilds
  bool _isMapLoading = false;
  bool _isDataLoading = false;
  bool _isImageLoading = false;
  
  // Error states
  String? _lastError;
  DateTime? _lastErrorTime;
  
  // Performance flags
  bool _useHighPerformanceMode = false;
  bool _enableBackgroundProcessing = true;
  int _maxConcurrentOperations = 3;
  
  // PHASE 1: Memory pressure detection
  bool _memoryPressureDetected = false;
  DateTime? _lastMemoryPressureTime;
  Timer? _memoryMonitorTimer;
  final List<int> _memoryUsageHistory = []; // Track memory usage over time
  // Note: Critical threshold reserved for future enhanced memory monitoring
  
  // Memory pressure callbacks
  final List<VoidCallback> _memoryPressureCallbacks = [];

  // Getters
  bool get isMapLoading => _isMapLoading;
  bool get isDataLoading => _isDataLoading;
  bool get isImageLoading => _isImageLoading;
  bool get hasAnyLoading => _isMapLoading || _isDataLoading || _isImageLoading;
  String? get lastError => _lastError;
  double get averageFps => _averageFps;
  bool get useHighPerformanceMode => _useHighPerformanceMode;
  bool get enableBackgroundProcessing => _enableBackgroundProcessing;
  int get maxConcurrentOperations => _maxConcurrentOperations;
  
  // PHASE 1: Memory pressure getters
  bool get memoryPressureDetected => _memoryPressureDetected;
  DateTime? get lastMemoryPressureTime => _lastMemoryPressureTime;
  
  // Performance metrics
  bool get isPerformanceGood => _averageFps > 50.0;
  bool get isPerformancePoor => _averageFps < 30.0;

  /// Constructor with memory monitoring
  PerformanceProvider() {
    _startMemoryMonitoring();
  }
  
  /// PHASE 1: Start monitoring memory usage
  void _startMemoryMonitoring() {
    // Only monitor on mobile platforms
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _memoryMonitorTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _checkMemoryPressure();
      });
      AppLogger.d('[PerformanceProvider] Memory monitoring started');
    }
  }
  
  /// PHASE 1: Check for memory pressure (simplified approach)
  void _checkMemoryPressure() {
    try {
      // This is a simplified check - in a real app you might use
      // platform channels to get actual memory usage
      
      // Check if we have performance issues that might indicate memory pressure
      final hasPerformanceIssues = _averageFps < 30.0;
      final hasLowMemoryIndicators = _useHighPerformanceMode;
      
      // Simple heuristic: if performance is poor and we're in high-performance mode,
      // assume memory pressure
      final newMemoryPressure = hasPerformanceIssues && hasLowMemoryIndicators;
      
      if (newMemoryPressure != _memoryPressureDetected) {
        _memoryPressureDetected = newMemoryPressure;
        
        if (_memoryPressureDetected) {
          _lastMemoryPressureTime = DateTime.now();
          _handleMemoryPressure();
          AppLogger.w('[PerformanceProvider] Memory pressure detected');
        } else {
          AppLogger.i('[PerformanceProvider] Memory pressure relieved');
        }
        
        notifyListeners();
      }
    } catch (e) {
      AppLogger.e('[PerformanceProvider] Error checking memory pressure', e);
    }
  }
  
  /// PHASE 1: Handle memory pressure by triggering callbacks
  void _handleMemoryPressure() {
    AppLogger.w('[PerformanceProvider] Handling memory pressure - triggering cache clearing');
    
    // Trigger all registered memory pressure callbacks
    for (final callback in _memoryPressureCallbacks) {
      try {
        callback();
      } catch (e) {
        AppLogger.e('[PerformanceProvider] Error in memory pressure callback', e);
      }
    }
    
    // Adjust performance settings for memory conservation
    if (!_useHighPerformanceMode) {
      _useHighPerformanceMode = true;
      _maxConcurrentOperations = 1; // Severely limit concurrent operations
      AppLogger.w('[PerformanceProvider] Activated emergency performance mode due to memory pressure');
    }
  }
  
  /// PHASE 1: Register callback for memory pressure events
  void registerMemoryPressureCallback(VoidCallback callback) {
    _memoryPressureCallbacks.add(callback);
    AppLogger.d('[PerformanceProvider] Memory pressure callback registered (${_memoryPressureCallbacks.length} total)');
  }
  
  /// PHASE 1: Unregister memory pressure callback
  void unregisterMemoryPressureCallback(VoidCallback callback) {
    _memoryPressureCallbacks.remove(callback);
    AppLogger.d('[PerformanceProvider] Memory pressure callback unregistered (${_memoryPressureCallbacks.length} remaining)');
  }
  
  /// PHASE 1: Manually trigger memory pressure handling (for testing/emergency)
  void triggerMemoryPressureHandling() {
    AppLogger.w('[PerformanceProvider] Manually triggering memory pressure handling');
    _memoryPressureDetected = true;
    _lastMemoryPressureTime = DateTime.now();
    _handleMemoryPressure();
    notifyListeners();
  }

  /// Update map loading state without affecting other loading states
  void setMapLoading(bool isLoading) {
    if (_isMapLoading != isLoading) {
      _isMapLoading = isLoading;
      notifyListeners();
    }
  }
  
  /// Update data loading state without affecting other loading states
  void setDataLoading(bool isLoading) {
    if (_isDataLoading != isLoading) {
      _isDataLoading = isLoading;
      notifyListeners();
    }
  }
  
  /// Update image loading state without affecting other loading states
  void setImageLoading(bool isLoading) {
    if (_isImageLoading != isLoading) {
      _isImageLoading = isLoading;
      notifyListeners();
    }
  }
  
  /// Set error state with automatic clearing
  void setError(String error) {
    _lastError = error;
    _lastErrorTime = DateTime.now();
    notifyListeners();
    
    // Auto-clear error after 10 seconds
    Timer(const Duration(seconds: 10), () {
      if (_lastError == error) {
        clearError();
      }
    });
  }
  
  /// Clear error state
  void clearError() {
    if (_lastError != null) {
      _lastError = null;
      _lastErrorTime = null;
      notifyListeners();
    }
  }
  
  /// Record frame timing for performance monitoring
  void recordFrameTime() {
    final now = DateTime.now();
    
    if (_lastFrameTime != null) {
      final frameDuration = now.difference(_lastFrameTime!);
      _frameTimes.add(frameDuration);
      
      // Keep only recent frame times
      if (_frameTimes.length > _frameHistoryLimit) {
        _frameTimes.removeAt(0);
      }
      
      // Calculate average FPS
      if (_frameTimes.isNotEmpty) {
        final avgFrameTime = _frameTimes.fold<Duration>(
          Duration.zero,
          (sum, duration) => sum + duration,
        ) ~/ _frameTimes.length;
        
        _averageFps = 1000.0 / avgFrameTime.inMilliseconds;
      }
    }
    
    _lastFrameTime = now;
    _frameCount++;
    
    // Update performance mode based on FPS
    _updatePerformanceMode();
  }
  
  /// Update performance mode based on current FPS
  void _updatePerformanceMode() {
    final shouldUseHighPerformance = _averageFps < 45.0;
    
    if (_useHighPerformanceMode != shouldUseHighPerformance) {
      _useHighPerformanceMode = shouldUseHighPerformance;
      
      // Adjust settings for performance mode
      if (_useHighPerformanceMode) {
        _maxConcurrentOperations = 2; // Reduce concurrent operations
        AppLogger.i('[PerformanceProvider] Enabling high-performance mode (FPS: ${_averageFps.toStringAsFixed(1)})');
      } else {
        _maxConcurrentOperations = 3; // Normal concurrent operations
        AppLogger.i('[PerformanceProvider] Using normal performance mode (FPS: ${_averageFps.toStringAsFixed(1)})');
      }
      
      // Don't notify listeners for performance mode changes to avoid rebuilds
      // This is an internal optimization setting
    }
  }
  
  /// Enable/disable background processing
  void setBackgroundProcessing(bool enabled) {
    if (_enableBackgroundProcessing != enabled) {
      _enableBackgroundProcessing = enabled;
      AppLogger.i('[PerformanceProvider] Background processing: ${enabled ? 'enabled' : 'disabled'}');
      notifyListeners();
    }
  }
  
  /// Get performance summary for debugging
  Map<String, dynamic> getPerformanceSummary() {
    return {
      'averageFps': _averageFps,
      'frameCount': _frameCount,
      'isPerformanceGood': isPerformanceGood,
      'isPerformancePoor': isPerformancePoor,
      'useHighPerformanceMode': _useHighPerformanceMode,
      'recentFrameTimes': _frameTimes.map((d) => d.inMilliseconds).toList(),
      'hasAnyLoading': hasAnyLoading,
      'lastError': _lastError,
      'lastErrorTime': _lastErrorTime?.toIso8601String(),
      'memoryPressureDetected': _memoryPressureDetected,
      'lastMemoryPressureTime': _lastMemoryPressureTime?.toIso8601String(),
      'memoryPressureCallbacks': _memoryPressureCallbacks.length,
    };
  }
  
  /// Reset performance metrics
  void resetPerformanceMetrics() {
    _frameTimes.clear();
    _frameCount = 0;
    _lastFrameTime = null;
    _averageFps = 60.0;
    _useHighPerformanceMode = false;
    _maxConcurrentOperations = 3;
    
    // PHASE 1: Reset memory pressure state
    _memoryPressureDetected = false;
    _lastMemoryPressureTime = null;
    _memoryUsageHistory.clear();
    
    AppLogger.i('[PerformanceProvider] Performance metrics reset');
  }
  
  /// PHASE 1: Enhanced dispose with cleanup
  @override
  void dispose() {
    _memoryMonitorTimer?.cancel();
    _memoryPressureCallbacks.clear();
    AppLogger.d('[PerformanceProvider] PerformanceProvider disposed');
    super.dispose();
  }
}

/// Mixin for widgets that want to monitor their performance impact
mixin PerformanceAware {
  late final Stopwatch _buildStopwatch = Stopwatch();
  
  void startBuildTiming() {
    _buildStopwatch.reset();
    _buildStopwatch.start();
  }
  
  void endBuildTiming(String widgetName) {
    _buildStopwatch.stop();
    final buildTime = _buildStopwatch.elapsedMilliseconds;
    
    if (buildTime > 16) { // More than one frame (60fps = 16.67ms per frame)
      AppLogger.w('[Performance] $widgetName build took ${buildTime}ms (> 16ms threshold)');
    }
  }
} 