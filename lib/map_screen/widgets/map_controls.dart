import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/performance_provider.dart';

/// Control size options independent of performance mode
enum ControlSize { mini, normal, large }

/// Map controls widget with floating action buttons for camera and marker navigation
/// Controls maintain consistent size regardless of performance conditions
class MapControls extends StatelessWidget with PerformanceAware {
  final VoidCallback onResetView;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onRotateLeft;
  final VoidCallback onRotateRight;
  final VoidCallback onIncreasePitch;
  final VoidCallback onDecreasePitch;
  final VoidCallback onPreviousMarker;
  final VoidCallback onNextMarker;
  final bool canNavigateMarkers;
  final double bottomPadding; // Added padding for bottom sheet
  
  // New size management properties
  final ControlSize controlSize;
  final bool maintainFixedSize;
  final bool enablePerformanceOptimizations;
  final bool isDarkMode; // Added for theme awareness

  MapControls({
    super.key,
    required this.onResetView,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onIncreasePitch,
    required this.onDecreasePitch,
    required this.onPreviousMarker,
    required this.onNextMarker,
    required this.canNavigateMarkers,
    this.bottomPadding = 0.0,
    this.controlSize = ControlSize.normal, // Default to normal size
    this.maintainFixedSize = true, // Default to fixed size
    this.enablePerformanceOptimizations = true, // Keep performance optimizations
    required this.isDarkMode, // Make isDarkMode required
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PerformanceProvider>(
      builder: (context, performanceProvider, child) {
        return Stack(
          children: [
            // Home button (bottom left)
            Positioned(
              left: 16,
              bottom: 140 + bottomPadding, // Account for bottom sheet
              child: _buildControlButton(
                icon: Icons.home,
                onPressed: onResetView,
                tooltip: 'Home View',
                heroTag: 'home',
                // backgroundColor is now determined in _buildControlButton
                performanceProvider: performanceProvider,
              ),
            ),

            // Zoom controls (right side)
            Positioned(
              right: 16,
              bottom: 200 + bottomPadding, // Increased spacing between controls
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildControlButton(
                    icon: Icons.add,
                    onPressed: onZoomIn,
                    tooltip: 'Zoom In',
                    heroTag: 'zoom_in',
                    performanceProvider: performanceProvider,
                  ),
                  const SizedBox(height: 8),
                  _buildControlButton(
                    icon: Icons.remove,
                    onPressed: onZoomOut,
                    tooltip: 'Zoom Out',
                    heroTag: 'zoom_out',
                    performanceProvider: performanceProvider,
                  ),
                ],
              ),
            ),

            // Rotation controls (right side, middle)
            Positioned(
              right: 16,
              bottom: 320 + bottomPadding, // Account for zoom controls and padding
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildControlButton(
                    icon: Icons.rotate_left,
                    onPressed: onRotateLeft,
                    tooltip: 'Rotate Left',
                    heroTag: 'rotate_left',
                    performanceProvider: performanceProvider,
                  ),
                  const SizedBox(height: 8),
                  _buildControlButton(
                    icon: Icons.rotate_right,
                    onPressed: onRotateRight,
                    tooltip: 'Rotate Right',
                    heroTag: 'rotate_right',
                    performanceProvider: performanceProvider,
                  ),
                ],
              ),
            ),

            // Pitch controls (right side, upper)
            Positioned(
              right: 16,
              bottom: 440 + bottomPadding, // Account for other controls and padding
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildControlButton(
                    icon: Icons.keyboard_arrow_up,
                    onPressed: onIncreasePitch,
                    tooltip: 'Increase Pitch',
                    heroTag: 'pitch_up',
                    performanceProvider: performanceProvider,
                  ),
                  const SizedBox(height: 8),
                  _buildControlButton(
                    icon: Icons.keyboard_arrow_down,
                    onPressed: onDecreasePitch,
                    tooltip: 'Decrease Pitch',
                    heroTag: 'pitch_down',
                    performanceProvider: performanceProvider,
                  ),
                ],
              ),
            ),

            // Marker navigation controls (left side) - Only show if there are markers
            if (canNavigateMarkers) ...[
              Positioned(
                left: 16,
                bottom: 200 + bottomPadding, // Account for bottom sheet
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildControlButton(
                      icon: Icons.skip_previous,
                      onPressed: onPreviousMarker,
                      tooltip: 'Previous Marker',
                      heroTag: 'prev_marker',
                      isNavigationControl: true, // Differentiate navigation controls for styling
                      performanceProvider: performanceProvider,
                    ),
                    const SizedBox(height: 8),
                    _buildControlButton(
                      icon: Icons.skip_next,
                      onPressed: onNextMarker,
                      tooltip: 'Next Marker',
                      heroTag: 'next_marker',
                      isNavigationControl: true, // Differentiate navigation controls for styling
                      performanceProvider: performanceProvider,
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// Build a control button with independent size management and performance optimizations
  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    required String heroTag,
    // required Color backgroundColor, // Removed, will be determined by isDarkMode
    bool isNavigationControl = false, // Added to style navigation buttons differently
    required PerformanceProvider performanceProvider,
  }) {
    // Performance optimizations (non-visual)
    final bool useAnimations = enablePerformanceOptimizations ? 
        !performanceProvider.useHighPerformanceMode : true;
    final bool shouldDebounce = enablePerformanceOptimizations && 
        performanceProvider.useHighPerformanceMode;
    
    // Size management - independent of performance mode
    final bool isMiniFAB = maintainFixedSize ? 
        (controlSize == ControlSize.mini) : 
        performanceProvider.useHighPerformanceMode; // Fallback to old behavior if not maintaining fixed size
    
    final double iconSize = _getIconSize();
    final double elevation = _getElevation(performanceProvider);

    // Determine colors based on isDarkMode and control type
    final Color fabBackgroundColor;
    final Color fabForegroundColor;

    if (isDarkMode) {
      fabBackgroundColor = isNavigationControl ? Colors.blueGrey[700]! : Colors.grey[800]!;
      fabForegroundColor = Colors.white;
    } else {
      fabBackgroundColor = isNavigationControl ? Colors.blue : Colors.white;
      fabForegroundColor = isNavigationControl ? Colors.white : Colors.black87;
    }
    
    return AnimatedContainer(
      duration: useAnimations ? const Duration(milliseconds: 200) : Duration.zero,
      child: FloatingActionButton(
        heroTag: heroTag,
        onPressed: () {
          // Debounce button presses for performance optimization
          if (shouldDebounce) {
            Future.delayed(const Duration(milliseconds: 50), onPressed);
          } else {
            onPressed();
          }
        },
        tooltip: tooltip,
        backgroundColor: fabBackgroundColor,
        foregroundColor: fabForegroundColor,
        mini: isMiniFAB,
        elevation: elevation,
        child: Icon(
          icon,
          size: iconSize,
        ),
      ),
    );
  }

  /// Get icon size based on control size setting
  double _getIconSize() {
    switch (controlSize) {
      case ControlSize.mini:
        return 20.0;
      case ControlSize.normal:
        return 24.0;
      case ControlSize.large:
        return 28.0;
    }
  }

  /// Get elevation with optional performance optimization
  double _getElevation(PerformanceProvider performanceProvider) {
    if (enablePerformanceOptimizations && performanceProvider.useHighPerformanceMode) {
      // Reduce elevation for better GPU performance
      return 2.0;
    }
    
    // Standard elevation based on control size
    switch (controlSize) {
      case ControlSize.mini:
        return 4.0;
      case ControlSize.normal:
        return 6.0;
      case ControlSize.large:
        return 8.0;
    }
  }
} 