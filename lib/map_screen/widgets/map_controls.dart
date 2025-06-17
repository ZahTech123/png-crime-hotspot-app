import 'package:flutter/material.dart';

class MapControls extends StatelessWidget {
  final VoidCallback? onResetView;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final VoidCallback? onRotateLeft;
  final VoidCallback? onRotateRight;
  final VoidCallback? onIncreasePitch;
  final VoidCallback? onDecreasePitch;
  final VoidCallback? onPreviousMarker;
  final VoidCallback? onNextMarker;
  final bool canNavigateMarkers;

  const MapControls({
    Key? key,
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
  }) : super(key: key);

  // --- Helper Widget for Control Buttons (copied from map_screen.dart) ---
  Widget _buildControlButton(IconData icon, VoidCallback? onPressed, {String? tooltip}) {
    // Disable button visually if onPressed is null
    bool isDisabled = onPressed == null;

    return Material(
      color: isDisabled ? Colors.grey.withOpacity(0.6) : Colors.white.withOpacity(0.9),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      elevation: isDisabled ? 0.0 : 4.0,
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: isDisabled ? Colors.white.withOpacity(0.7) : Colors.black87),
        onPressed: onPressed,
        padding: const EdgeInsets.all(10.0),
        constraints: const BoxConstraints(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Grouping controls for better positioning
        Positioned(
          top: 20,
          left: 20,
          child: _buildControlButton(
            Icons.home, // Or Icons.fullscreen
            onResetView,
            tooltip: "Reset View",
          ),
        ),
        Positioned(
          top: 70, // MOVE DOWN below default compass position
          right: 20,
          child: Column( // Zoom Controls
            children: [
              _buildControlButton(Icons.zoom_in, onZoomIn, tooltip: "Zoom In"),
              const SizedBox(height: 10), // Standardized spacing
              _buildControlButton(Icons.zoom_out, onZoomOut, tooltip: "Zoom Out"),
            ],
          ),
        ),
        Positioned(
          bottom: 220, // Increased bottom to clear carousel and navbar
          left: 20,
          child: Column( // Marker Navigation Controls
            children: [
              _buildControlButton(
                Icons.arrow_back_ios, // Previous
                canNavigateMarkers ? onPreviousMarker : null,
                tooltip: "Previous Complaint Location",
              ),
              const SizedBox(height: 10), // Standardized spacing
              _buildControlButton(
                Icons.arrow_forward_ios, // Next
                canNavigateMarkers ? onNextMarker : null,
                tooltip: "Next Complaint Location",
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 130, // Increased bottom to clear carousel and navbar
          right: 20,
          child: Column( // Rotate and Pitch Controls
            crossAxisAlignment: CrossAxisAlignment.end, // Align buttons to the right if needed
            children: [
              Row( // Rotate buttons side-by-side
                mainAxisSize: MainAxisSize.min, // Prevent row from taking full width
                children: [
                  _buildControlButton(Icons.rotate_left, onRotateLeft, tooltip: "Rotate Left"),
                  const SizedBox(width: 10), // Standardized spacing
                  _buildControlButton(Icons.rotate_right, onRotateRight, tooltip: "Rotate Right"),
                ],
              ),
              const SizedBox(height: 10), // Standardized spacing
              Row( // Pitch buttons side-by-side
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildControlButton(Icons.keyboard_arrow_down, onDecreasePitch, tooltip: "Decrease Pitch (Tilt Down)"),
                  const SizedBox(width: 10), // Standardized spacing
                  _buildControlButton(Icons.keyboard_arrow_up, onIncreasePitch, tooltip: "Increase Pitch (Tilt Up)"),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
} 