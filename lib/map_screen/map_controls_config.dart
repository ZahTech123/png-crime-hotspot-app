import 'package:flutter/material.dart';
import 'widgets/map_controls.dart';

/// Configuration class for map controls appearance and behavior
/// Provides easy customization of control sizing and performance settings
class MapControlsConfig {
  /// Size of the control buttons
  final ControlSize controlSize;
  
  /// Whether to maintain fixed size regardless of performance conditions
  final bool maintainFixedSize;
  
  /// Whether to enable performance optimizations (animations, debouncing, elevation)
  final bool enablePerformanceOptimizations;
  
  /// Custom spacing between control groups
  final double controlSpacing;
  
  /// Custom padding from screen edges
  final double edgePadding;
  
  /// Background colors for different control types
  final Color primaryControlColor;
  final Color navigationControlColor;
  
  /// Whether to show marker navigation controls
  final bool showMarkerNavigation;

  const MapControlsConfig({
    this.controlSize = ControlSize.mini,
    this.maintainFixedSize = true,
    this.enablePerformanceOptimizations = true,
    this.controlSpacing = 8.0,
    this.edgePadding = 16.0,
    this.primaryControlColor = Colors.white,
    this.navigationControlColor = Colors.blue,
    this.showMarkerNavigation = true,
  });

  /// Create a copy with modified properties
  MapControlsConfig copyWith({
    ControlSize? controlSize,
    bool? maintainFixedSize,
    bool? enablePerformanceOptimizations,
    double? controlSpacing,
    double? edgePadding,
    Color? primaryControlColor,
    Color? navigationControlColor,
    bool? showMarkerNavigation,
  }) {
    return MapControlsConfig(
      controlSize: controlSize ?? this.controlSize,
      maintainFixedSize: maintainFixedSize ?? this.maintainFixedSize,
      enablePerformanceOptimizations: enablePerformanceOptimizations ?? this.enablePerformanceOptimizations,
      controlSpacing: controlSpacing ?? this.controlSpacing,
      edgePadding: edgePadding ?? this.edgePadding,
      primaryControlColor: primaryControlColor ?? this.primaryControlColor,
      navigationControlColor: navigationControlColor ?? this.navigationControlColor,
      showMarkerNavigation: showMarkerNavigation ?? this.showMarkerNavigation,
    );
  }
} 