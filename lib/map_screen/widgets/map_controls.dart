import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/performance_provider.dart';

/// Map controls widget with floating action buttons for camera and marker navigation
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
              child: _buildPerformanceAwareButton(
                icon: Icons.home,
                onPressed: onResetView,
                tooltip: 'Home View',
                heroTag: 'home',
                backgroundColor: Colors.white,
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
                  _buildPerformanceAwareButton(
                    icon: Icons.add,
                    onPressed: onZoomIn,
                    tooltip: 'Zoom In',
                    heroTag: 'zoom_in',
                    backgroundColor: Colors.white,
                    performanceProvider: performanceProvider,
                  ),
                  const SizedBox(height: 8),
                  _buildPerformanceAwareButton(
                    icon: Icons.remove,
                    onPressed: onZoomOut,
                    tooltip: 'Zoom Out',
                    heroTag: 'zoom_out',
                    backgroundColor: Colors.white,
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
                  _buildPerformanceAwareButton(
                    icon: Icons.rotate_left,
                    onPressed: onRotateLeft,
                    tooltip: 'Rotate Left',
                    heroTag: 'rotate_left',
                    backgroundColor: Colors.white,
                    performanceProvider: performanceProvider,
                  ),
                  const SizedBox(height: 8),
                  _buildPerformanceAwareButton(
                    icon: Icons.rotate_right,
                    onPressed: onRotateRight,
                    tooltip: 'Rotate Right',
                    heroTag: 'rotate_right',
                    backgroundColor: Colors.white,
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
                  _buildPerformanceAwareButton(
                    icon: Icons.keyboard_arrow_up,
                    onPressed: onIncreasePitch,
                    tooltip: 'Increase Pitch',
                    heroTag: 'pitch_up',
                    backgroundColor: Colors.white,
                    performanceProvider: performanceProvider,
                  ),
                  const SizedBox(height: 8),
                  _buildPerformanceAwareButton(
                    icon: Icons.keyboard_arrow_down,
                    onPressed: onDecreasePitch,
                    tooltip: 'Decrease Pitch',
                    heroTag: 'pitch_down',
                    backgroundColor: Colors.white,
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
                    _buildPerformanceAwareButton(
                      icon: Icons.skip_previous,
                      onPressed: onPreviousMarker,
                      tooltip: 'Previous Marker',
                      heroTag: 'prev_marker',
                      backgroundColor: Colors.blue,
                      performanceProvider: performanceProvider,
                    ),
                    const SizedBox(height: 8),
                    _buildPerformanceAwareButton(
                      icon: Icons.skip_next,
                      onPressed: onNextMarker,
                      tooltip: 'Next Marker',
                      heroTag: 'next_marker',
                      backgroundColor: Colors.blue,
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

  /// Build a performance-aware floating action button
  Widget _buildPerformanceAwareButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    required String heroTag,
    required Color backgroundColor,
    required PerformanceProvider performanceProvider,
  }) {
    // Disable animations completely in high-performance mode
    final useAnimations = !performanceProvider.useHighPerformanceMode;
    
    return AnimatedContainer(
      duration: useAnimations ? const Duration(milliseconds: 200) : Duration.zero,
      child: FloatingActionButton(
        heroTag: heroTag,
        onPressed: () {
          // Debounce button presses in performance mode
          if (performanceProvider.useHighPerformanceMode) {
            Future.delayed(const Duration(milliseconds: 50), onPressed);
          } else {
            onPressed();
          }
        },
        tooltip: tooltip,
        backgroundColor: backgroundColor,
        foregroundColor: backgroundColor == Colors.blue ? Colors.white : Colors.black87,
        mini: performanceProvider.useHighPerformanceMode, // Use mini buttons in performance mode
        elevation: performanceProvider.useHighPerformanceMode ? 2.0 : 6.0, // Reduce elevation for performance
        child: Icon(
          icon,
          size: performanceProvider.useHighPerformanceMode ? 20.0 : 24.0,
        ),
      ),
    );
  }
} 