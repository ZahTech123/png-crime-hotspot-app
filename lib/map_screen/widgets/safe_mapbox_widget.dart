import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:ncdc_ccms_app/utils/logger.dart';

// ======== SAFE MAPBOX WIDGET WRAPPER ========
// This wrapper ensures proper lifecycle management for MapboxMap
class SafeMapboxWidget extends StatefulWidget {
  final Function(mapbox.MapboxMap) onMapCreated;
  final Function(mapbox.StyleLoadedEventData)? onStyleLoadedListener;
  final Function(mapbox.CameraChangedEventData)? onCameraChangeListener;
  final mapbox.CameraOptions cameraOptions;
  final String styleUri;
  final bool textureView;

  const SafeMapboxWidget({
    super.key,
    required this.onMapCreated,
    this.onStyleLoadedListener,
    this.onCameraChangeListener,
    required this.cameraOptions,
    required this.styleUri,
    this.textureView = true,
  });

  @override
  State<SafeMapboxWidget> createState() => _SafeMapboxWidgetState();
}

class _SafeMapboxWidgetState extends State<SafeMapboxWidget> {
  mapbox.MapboxMap? _mapInstance;
  bool _isDisposing = false;

  // Custom wrapper for onMapCreated
  void _handleMapCreated(mapbox.MapboxMap map) {
    if (_isDisposing || !mounted) return;

    _mapInstance = map;
    widget.onMapCreated(map);
  }

  // Custom wrapper for style loaded
  void _handleStyleLoaded(mapbox.StyleLoadedEventData data) {
    if (_isDisposing || !mounted || widget.onStyleLoadedListener == null) return;

    widget.onStyleLoadedListener!(data);
  }

  // Custom wrapper for camera changed
  void _handleCameraChanged(mapbox.CameraChangedEventData data) {
    if (_isDisposing || !mounted || widget.onCameraChangeListener == null) return;
    widget.onCameraChangeListener!(data);
  }

  @override
  void dispose() {
    _isDisposing = true;

    final map = _mapInstance;
    _mapInstance = null;

    try {
      if (map != null) {
        map.dispose();
        AppLogger.d("SafeMapboxWidget: Map successfully disposed");
      }
    } catch (e) {
      AppLogger.e("SafeMapboxWidget: Error during disposal", e);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return mapbox.MapWidget(
      key: const ValueKey("safeMapWidget"),
      cameraOptions: widget.cameraOptions,
      styleUri: widget.styleUri,
      onMapCreated: _handleMapCreated,
      onStyleLoadedListener: _handleStyleLoaded,
      onCameraChangeListener: _handleCameraChanged,
      textureView: widget.textureView,
    );
  }
}