import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Ensure flutter_dotenv is initialized in main.dart:
// await dotenv.load(fileName: ".env");

/// StatefulWidget that displays a Mapbox map and manages its interactions.
///
/// This widget is responsible for initializing the map, adding markers (annotations)
/// based on input data, handling map camera changes, and providing user controls
/// for map manipulation (zoom, rotation, pitch). It also handles marker tap events.
class MapWidget extends StatefulWidget {
  final mapbox.CameraOptions initialCameraOptions;
  final String styleUri;
  final bool textureView;
  final List<mapbox.PointAnnotationOptions> complaintsDataForAnnotations; // Pre-processed options
  // final Map<String, String> annotationToComplaintIdMap; // No longer needed directly
  final Map<String, int> complaintIdToDataIndexMap; // For callback indexing
  final Function(mapbox.MapboxMap map) onMapCreatedCallback;
  final Function() onStyleLoadedCallback;
  final Function(mapbox.CameraState cameraState) onCameraIdleCallback;
  final Function(String complaintId) onMarkerTappedCallback;

  const MapWidget({
    Key? key,
    required this.initialCameraOptions,
    required this.styleUri,
    this.textureView = false,
    required this.complaintsDataForAnnotations,
    // required this.annotationToComplaintIdMap,
    required this.complaintIdToDataIndexMap,
    required this.onMapCreatedCallback,
    required this.onStyleLoadedCallback,
    required this.onCameraIdleCallback,
    required this.onMarkerTappedCallback,
  }) : super(key: key);

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  mapbox.MapboxMap? mapboxMap; // The core Mapbox map controller.
  bool _isDisposed = false; // Flag to track if the widget is disposed.
  mapbox.PointAnnotationManager? _pointAnnotationManager; // Manages point annotations on the map.

  int _currentMarkerIndex = 0; // Tracks the index of the complaint associated with the last tapped marker.
  final Map<String, mapbox.PointAnnotation> _activeAnnotations = {}; // Stores current PointAnnotation objects by their Mapbox-generated ID.
  double _currentZoom = 14.0; // Holds the current zoom level of the map. Initialized from widget or map state.
  Timer? _debounceTimer; // Timer to debounce rapid camera change events.
  static const double _initialIconSizeFactor = 1.0; // Base factor for calculating marker icon sizes.

  // Internal map from Mapbox-generated annotation ID to our application-specific complaint ID.
  final Map<String, String> _internalAnnotationIdToComplaintId = {};
  final Set<String> _bouncingAnnotationIds = {}; // Tracks IDs of annotations currently undergoing a bounce animation.

  // Constants for map manipulation increments.
  static const double _zoomIncrement = 0.5;
  static const double _bearingIncrement = 15.0;
  static const double _pitchIncrement = 5.0;
  static const double _maxPitch = 60.0;

  @override
  void initState() {
    super.initState();
    _currentZoom = widget.initialCameraOptions.zoom ?? _currentZoom;
    if (kDebugMode) print("MapWidget: initState - Initial zoom: $_currentZoom");
  }

  @override
  void didUpdateWidget(covariant MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool dataChanged = widget.complaintsDataForAnnotations != oldWidget.complaintsDataForAnnotations ||
                       widget.complaintIdToDataIndexMap != oldWidget.complaintIdToDataIndexMap;

    if (dataChanged && mapboxMap != null && !_isDisposed) {
      if (kDebugMode) print("MapWidget: Input data changed, re-adding markers.");
      _addMarkers();
    }
    if (widget.initialCameraOptions != oldWidget.initialCameraOptions && mapboxMap != null && !_isDisposed) {
      mapboxMap!.flyTo(widget.initialCameraOptions, mapbox.MapAnimationOptions(duration: 300));
      _currentZoom = widget.initialCameraOptions.zoom ?? _currentZoom;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _debounceTimer?.cancel();

    if (_pointAnnotationManager != null) {
      try {
        // Check if the listener is actually part of a public API for removal.
        // If not, this might error or be unnecessary if manager is disposed with map.
        // _pointAnnotationManager!.removeOnPointAnnotationClickListener(_AnnotationClickListener(this));
      } catch (e) {
        if (kDebugMode) print("MapWidget: Error removing annotation click listener during dispose: $e");
      }
    }
    _pointAnnotationManager = null;

    try {
      // Using mapboxMap?.destroy() or mapboxMap?.dispose()
      // Based on common patterns, dispose is usually the method. If destroy is specific, use that.
      mapboxMap?.dispose();
    } catch (e) {
      if (kDebugMode) print("MapWidget: Error disposing map: $e");
    }
    mapboxMap = null;

    if (kDebugMode) print("MapWidget disposed.");
    super.dispose();
  }

  /// Cancels ongoing map operations. This might be called before navigating away.
  /// Note: Full resource cleanup is in dispose. This is for explicit interruption.
  void cancelMapOperations() {
    if (mapboxMap == null || _isDisposed) return;
    // Example: Stop camera animations
    mapboxMap!.easeTo(mapboxMap!.getCameraState().toCameraOptions(), mapbox.MapAnimationOptions(duration: 0));
    if (kDebugMode) print("MapWidget: Ongoing map operations (like camera flight) cancelled.");
  }


  void _onMapCreated(mapbox.MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    this.mapboxMap!.subscribe(_onCameraChanged, [mapbox.MapEvents.cameraChanged]);

    try {
      final currentMapZoom = this.mapboxMap!.getCameraState().zoom;
      if ((currentMapZoom - _currentZoom).abs() > 0.01) {
         _currentZoom = currentMapZoom;
      }
    } catch(e) {
      if (kDebugMode) print("MapWidget: Error getting initial zoom from map: $e");
    }
    widget.onMapCreatedCallback(mapboxMap);
  }

  void _onStyleLoadedCallback() {
    if (kDebugMode) print("MapWidget: Style loaded.");
    _addMarkers();
    widget.onStyleLoadedCallback();
  }

  void _onCameraChanged(mapbox.Event event) {
    if (_isDisposed || mapboxMap == null) return;
    final cameraState = mapboxMap!.getCameraState();

    bool zoomChanged = false;
    if ((cameraState.zoom - _currentZoom).abs() > 0.01) {
        setState(() { _currentZoom = cameraState.zoom; });
        zoomChanged = true;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      if (!_isDisposed) {
        if (zoomChanged) {
            _updateAnnotationSize(_currentZoom);
        }
        widget.onCameraIdleCallback(cameraState);
      }
    });
  }

  Future<void> _zoomIn() async {
    if (mapboxMap == null || _isDisposed) return;
    final currentMapZoom = mapboxMap!.getCameraState().zoom;
    mapboxMap!.flyTo(
      mapbox.CameraOptions(zoom: currentMapZoom + _zoomIncrement),
      mapbox.MapAnimationOptions(duration: 300),
    );
  }

  Future<void> _zoomOut() async {
    if (mapboxMap == null || _isDisposed) return;
    final currentMapZoom = mapboxMap!.getCameraState().zoom;
    mapboxMap!.flyTo(
      mapbox.CameraOptions(zoom: currentMapZoom - _zoomIncrement),
      mapbox.MapAnimationOptions(duration: 300),
    );
  }

  Future<void> _rotateLeft() async {
    if (mapboxMap == null || _isDisposed) return;
    final currentBearing = mapboxMap!.getCameraState().bearing;
    mapboxMap!.flyTo(
      mapbox.CameraOptions(bearing: currentBearing - _bearingIncrement),
      mapbox.MapAnimationOptions(duration: 300),
    );
  }

  Future<void> _rotateRight() async {
    if (mapboxMap == null || _isDisposed) return;
    final currentBearing = mapboxMap!.getCameraState().bearing;
    mapboxMap!.flyTo(
      mapbox.CameraOptions(bearing: currentBearing + _bearingIncrement),
      mapbox.MapAnimationOptions(duration: 300),
    );
  }

  Future<void> _increasePitch() async {
    if (mapboxMap == null || _isDisposed) return;
    final currentPitch = mapboxMap!.getCameraState().pitch;
    final newPitch = (currentPitch) + _pitchIncrement;
    mapboxMap!.flyTo(
      mapbox.CameraOptions(pitch: newPitch.clamp(0.0, _maxPitch)),
      mapbox.MapAnimationOptions(duration: 300),
    );
  }

  Future<void> _decreasePitch() async {
    if (mapboxMap == null || _isDisposed) return;
    final currentPitch = mapboxMap!.getCameraState().pitch;
    final newPitch = (currentPitch) - _pitchIncrement;
    mapboxMap!.flyTo(
      mapbox.CameraOptions(pitch: newPitch.clamp(0.0, _maxPitch)),
      mapbox.MapAnimationOptions(duration: 300),
    );
  }

  Future<void> _flyToCoordinate(Map<String, dynamic> coordinate, {double? zoom}) async {
    if (mapboxMap == null || _isDisposed) return;
    final targetZoom = zoom ?? mapboxMap!.getCameraState().zoom + 2.0;
    mapboxMap!.flyTo(
      mapbox.CameraOptions(
        center: mapbox.Point(coordinates: mapbox.Position(coordinate['lng'], coordinate['lat'])).toJson(),
        zoom: targetZoom,
        pitch: 45.0,
      ),
      mapbox.MapAnimationOptions(duration: 1500, startDelay: 0),
    );

    String? targetAnnotationId;
    final targetPosition = mapbox.Position(coordinate['lng'], coordinate['lat']);

    for (var entry in _activeAnnotations.entries) {
        final annotation = entry.value;
        if (annotation.geometry is Map) {
            final List<dynamic>? coords = (annotation.geometry as Map)['coordinates'] as List?;
            if (coords != null && coords.length == 2) {
                if ((coords[0] - targetPosition.lng).abs() < 0.00001 &&
                    (coords[1] - targetPosition.lat).abs() < 0.00001) {
                    targetAnnotationId = entry.key;
                    break;
                }
            }
        }
    }
    if (targetAnnotationId != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
            if (!_isDisposed) _animateMarkerBounce(targetAnnotationId!);
        });
    }
  }

  Future<void> _resetCameraView() async {
    if (mapboxMap == null || _isDisposed) return;

    if (_activeAnnotations.isNotEmpty) {
        List<mapbox.Point> pointsToFit = _activeAnnotations.values.map((annotation) {
            final geometryMap = annotation.geometry;
            if (geometryMap is Map<String?, Object?>) {
                final List<dynamic>? coords = geometryMap['coordinates'] as List?;
                if (coords != null && coords.length == 2) {
                    return mapbox.Point(coordinates: mapbox.Position(coords[0], coords[1]));
                }
            }
            return null;
        }).where((p) => p != null).cast<mapbox.Point>().toList();

        if (pointsToFit.isNotEmpty) {
            try {
                mapbox.CameraOptions cameraOptions = await mapboxMap!.cameraForCoordinates(
                    pointsToFit.map((p) => p.toJson()).toList(),
                    mapbox.MbxEdgeInsets(top: 100.0, left: 50.0, bottom: 100.0, right: 50.0),
                    null,
                    null
                );
                await mapboxMap!.flyTo(cameraOptions, mapbox.MapAnimationOptions(duration: 1500));
                _currentZoom = cameraOptions.zoom ?? _currentZoom;
            } catch (e) {
                 if (kDebugMode) print("MapWidget: Error calculating camera for coordinates: $e. Resetting to initial options.");
                 await mapboxMap!.flyTo(widget.initialCameraOptions, mapbox.MapAnimationOptions(duration: 1500));
                 _currentZoom = widget.initialCameraOptions.zoom ?? _currentZoom;
            }
            return;
        }
    }
    await mapboxMap!.flyTo(widget.initialCameraOptions, mapbox.MapAnimationOptions(duration: 1500));
    _currentZoom = widget.initialCameraOptions.zoom ?? _currentZoom;
  }

  Future<void> _addMarkers() async {
    if (mapboxMap == null || _isDisposed) {
      return;
    }

    if (_pointAnnotationManager != null) {
      try {
        await _pointAnnotationManager!.deleteAll();
      } catch (e) {
        if (kDebugMode) print("MapWidget: Error deleting existing annotations: $e");
      }
    }
    _activeAnnotations.clear();
    _internalAnnotationIdToComplaintId.clear();

    _pointAnnotationManager ??= await mapboxMap!.annotations.createPointAnnotationManager();
    try {
      _pointAnnotationManager!.removeOnPointAnnotationClickListener(_AnnotationClickListener(this));
    } catch (e) { /* Listener might not have been set yet, ignore */ }
    _pointAnnotationManager!.addOnPointAnnotationClickListener(_AnnotationClickListener(this));

    try {
      final ByteData bytes = await rootBundle.load('assets/icons/complaint-pin.png');
      final Uint8List list = bytes.buffer.asUint8List();
      await mapboxMap!.images.addRasterImage('complaint-icon-custom', list, true);
    } catch (e) {
      if (kDebugMode) print("MapWidget: Error loading marker image 'complaint-icon-custom': $e");
      return;
    }

    if (widget.complaintsDataForAnnotations.isEmpty) {
      return;
    }

    final initialCalculatedSize = _calculateIconSize(_currentZoom);
    final List<mapbox.PointAnnotationOptions> optionsWithIconAndData = [];

    for(final opt in widget.complaintsDataForAnnotations) {
        optionsWithIconAndData.add(
            mapbox.PointAnnotationOptions(
                geometry: opt.geometry,
                image: 'complaint-icon-custom',
                iconSize: initialCalculatedSize,
                data: opt.data
            )
        );
    }

    if (optionsWithIconAndData.isEmpty) {
        return;
    }

    final createdAnnotations = await _pointAnnotationManager?.createMulti(optionsWithIconAndData);

    if (createdAnnotations != null && createdAnnotations.isNotEmpty) {
      for (var annotation in createdAnnotations) {
        _activeAnnotations[annotation.id] = annotation;
        final complaintId = (annotation.data as Map<String, dynamic>?)?['complaintId'] as String?;
        if (complaintId != null) {
          _internalAnnotationIdToComplaintId[annotation.id] = complaintId;
        }
      }
      if (kDebugMode) print("MapWidget: Added ${createdAnnotations.length} markers.");
    }
    _updateAnnotationSize(_currentZoom, forceUpdate: true);
  }


  Future<void> _updateAnnotationSize(double currentZoom, {bool forceUpdate = false}) async {
    if (_pointAnnotationManager == null || _isDisposed || _activeAnnotations.isEmpty) return;

    final newIconSize = _calculateIconSize(currentZoom);

    final firstAnnotation = _activeAnnotations.values.first;
    if (!forceUpdate && firstAnnotation.iconSize != null && (newIconSize - firstAnnotation.iconSize!).abs() < 0.01) {
      return;
    }

    List<mapbox.PointAnnotation> annotationsToUpdate = [];
    for (var annotationEntry in _activeAnnotations.entries) {
      if (!_bouncingAnnotationIds.contains(annotationEntry.key)) {
        var updatedAnnotation = annotationEntry.value;
        updatedAnnotation.iconSize = newIconSize;
        annotationsToUpdate.add(updatedAnnotation);
      }
    }

    if (annotationsToUpdate.isNotEmpty) {
      try {
        await _pointAnnotationManager!.updateMulti(annotationsToUpdate);
      } catch (e) {
        if (kDebugMode) print("MapWidget: Error updating multiple annotations: $e");
      }
    }
  }

  double _calculateIconSize(double zoom) {
    if (zoom < 10) return _initialIconSizeFactor * 0.7;
    if (zoom < 11) return _initialIconSizeFactor * 0.8;
    if (zoom < 12) return _initialIconSizeFactor * 0.9;
    if (zoom < 13) return _initialIconSizeFactor * 1.0;
    if (zoom < 14) return _initialIconSizeFactor * 1.1;
    if (zoom < 15) return _initialIconSizeFactor * 1.2;
    if (zoom < 16) return _initialIconSizeFactor * 1.3;
    if (zoom < 17) return _initialIconSizeFactor * 1.4;
    return _initialIconSizeFactor * 1.5;
  }

  Future<void> _animateMarkerBounce(String annotationId) async {
    if (_pointAnnotationManager == null || !_activeAnnotations.containsKey(annotationId) || _isDisposed) {
        return;
    }

    _bouncingAnnotationIds.add(annotationId);
    final annotation = _activeAnnotations[annotationId]!;
    final baseSize = _calculateIconSize(_currentZoom);
    final bounceSize = baseSize * 1.6;
    const duration = Duration(milliseconds: 180);
    const iterations = 2;

    for (int i = 0; i < iterations; i++) {
      if (_isDisposed) return;
      var currentAnnotationState = _activeAnnotations[annotationId];
      if(currentAnnotationState == null) return;
      currentAnnotationState.iconSize = bounceSize;
      try { await _pointAnnotationManager!.update(currentAnnotationState); } catch (e) { if (kDebugMode) print("Bounce update error: $e"); }
      await Future.delayed(duration);

      if (_isDisposed) return;
      currentAnnotationState = _activeAnnotations[annotationId];
      if(currentAnnotationState == null) return;
      currentAnnotationState.iconSize = baseSize;
      try { await _pointAnnotationManager!.update(currentAnnotationState); } catch (e) { if (kDebugMode) print("Bounce update error: $e"); }
      await Future.delayed(duration);
    }
    _bouncingAnnotationIds.remove(annotationId);

    if (!_isDisposed) {
      var finalAnnotationState = _activeAnnotations[annotationId];
      if(finalAnnotationState != null) {
        finalAnnotationState.iconSize = _calculateIconSize(_currentZoom);
        try { await _pointAnnotationManager!.update(finalAnnotationState); } catch (e) { if (kDebugMode) print("Bounce final update error: $e"); }
      }
    }
  }

  void _onMarkerTapped(mapbox.PointAnnotation annotation) {
    if (_isDisposed) return;
    final complaintId = _internalAnnotationIdToComplaintId[annotation.id];

    if (complaintId != null) {
      final dataIndex = widget.complaintIdToDataIndexMap[complaintId];
      if (dataIndex != null) {
        setState(() { _currentMarkerIndex = dataIndex; });
        _animateMarkerBounce(annotation.id);
        widget.onMarkerTappedCallback(complaintId);
      } else {
         if (kDebugMode) print("MapWidget: Error - Complaint ID $complaintId from annotation ${annotation.id} not found in widget.complaintIdToDataIndexMap.");
      }
    } else {
      if (kDebugMode) print("MapWidget: Error - Tapped annotation ${annotation.id} has no mapping in _internalAnnotationIdToComplaintId.");
    }
  }

  @override
  Widget build(BuildContext context) {
    String? accessToken = dotenv.env['MAPBOX_ACCESS_TOKEN'];
    if (accessToken == null || accessToken.isEmpty || accessToken == 'YOUR_MAPBOX_ACCESS_TOKEN_REPLACE_ME') {
      if (kDebugMode) print("CRITICAL: MAPBOX_ACCESS_TOKEN is missing or invalid. Map cannot be displayed.");
      return const Center(
        child: Text(
          "Map Error: Configuration incomplete.\nPlease set MAPBOX_ACCESS_TOKEN.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      );
    }

    return mapbox.MapWidget(
      key: ValueKey("mapboxMapWidget_${widget.key?.toString() ?? 'noKey'}"),
      resourceOptions: mapbox.ResourceOptions(accessToken: accessToken),
      cameraOptions: widget.initialCameraOptions,
      styleUri: widget.styleUri,
      textureView: widget.textureView,
      onMapCreated: _onMapCreated,
      onStyleLoadedListener: (data) { _onStyleLoadedCallback(); },
    );
  }
}

/// Click listener for point annotations on the map.
/// Delegates tap events to the `_MapWidgetState._onMarkerTapped` method.
class _AnnotationClickListener extends mapbox.OnPointAnnotationClickListener {
  final _MapWidgetState _state;

  _AnnotationClickListener(this._state);

  @override
  void onPointAnnotationClick(mapbox.PointAnnotation annotation) {
    if (_state._isDisposed || !_state.mounted) return;
    _state._onMarkerTapped(annotation);
  }
}
>>>>>>> REPLACE
