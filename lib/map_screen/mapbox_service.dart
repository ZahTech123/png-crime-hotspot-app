import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import '../models.dart';

/// Service class to handle all Mapbox SDK interactions
class MapboxService {
  mapbox.MapboxMap? _mapboxMap;
  mapbox.PointAnnotationManager? _pointAnnotationManager;
  bool _isDisposed = false;
  Timer? _debounceTimer;

  // Constants
  static const double _zoomIncrement = 1.0;
  static const double _bearingIncrement = 30.0;
  static const double _pitchIncrement = 15.0;
  static const double _maxPitch = 70.0;
  static const int _animationDurationMs = 300;
  static const double _initialIconSize = 0.5;

  // Default camera view for reset
  static final mapbox.CameraOptions _initialCameraOptions = mapbox.CameraOptions(
    center: mapbox.Point(coordinates: mapbox.Position(147.1803, -9.4438)), // Port Moresby
    zoom: 12.0,
    pitch: 45.0,
    bearing: 0.0,
  );

  /// Initialize the service with a MapboxMap instance
  void initialize(mapbox.MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
  }

  /// Check if the service is properly initialized
  bool get isInitialized => _mapboxMap != null && !_isDisposed;

  /// Configure map gestures
  Future<void> configureGestures() async {
    if (!isInitialized) return;

    try {
      await _mapboxMap!.gestures.updateSettings(mapbox.GesturesSettings(
        rotateEnabled: true,
        pitchEnabled: true,
        scrollEnabled: true,
        doubleTapToZoomInEnabled: true,
        doubleTouchToZoomOutEnabled: true,
        quickZoomEnabled: true,
      ));
    } catch (e) {
      // Silently ignore gesture settings errors
    }
  }

  /// Configure map ornaments (scale bar, compass, etc.)
  Future<void> configureOrnaments() async {
    if (!isInitialized) return;

    try {
      // Scale Bar
      await _mapboxMap!.scaleBar.updateSettings(mapbox.ScaleBarSettings(
        position: mapbox.OrnamentPosition.BOTTOM_LEFT,
        marginLeft: 60.0,
        marginTop: 0.0,
        marginBottom: 35.0,
        marginRight: 0.0,
        isMetricUnits: true,
      ));

      // Compass
      await _mapboxMap!.compass.updateSettings(mapbox.CompassSettings(
        position: mapbox.OrnamentPosition.TOP_RIGHT,
        marginTop: 10.0,
        marginRight: 20.0,
        marginBottom: 0.0,
        marginLeft: 0.0,
      ));

      // Logo
      await _mapboxMap!.logo.updateSettings(mapbox.LogoSettings(
        position: mapbox.OrnamentPosition.BOTTOM_LEFT,
        marginLeft: 4.0,
        marginTop: 0.0,
        marginBottom: 4.0,
        marginRight: 0.0,
      ));

      // Attribution Button
      await _mapboxMap!.attribution.updateSettings(mapbox.AttributionSettings(
        position: mapbox.OrnamentPosition.BOTTOM_LEFT,
        marginLeft: 92.0,
        marginTop: 0.0,
        marginBottom: 2.0,
        marginRight: 0.0,
      ));
    } catch (e) {
      // Silently ignore ornament configuration errors
    }
  }

  /// Add 3D buildings to the map
  Future<void> add3DBuildings() async {
    if (!isInitialized) return;

    try {
      // Check if composite source exists
      bool compositeExists = false;
      try {
        compositeExists = await _mapboxMap!.style.styleSourceExists("composite");
      } catch (e) {
        // Silently ignore if source check fails
      }

      if (!compositeExists) return;

      // Define the 3D buildings layer
      final fillExtrusionLayer = mapbox.FillExtrusionLayer(
        id: "custom-3d-buildings",
        sourceId: "composite",
        sourceLayer: "building",
        minZoom: 14.0,
        filter: ['has', 'height'],
        fillExtrusionColor: 0xFF9E9E9E,
        fillExtrusionHeightExpression: ["get", "height"],
        fillExtrusionBaseExpression: ["get", "min_height"],
        fillExtrusionOpacity: 0.8,
      );

      await _mapboxMap!.style.addLayer(fillExtrusionLayer);
    } catch (e) {
      // Silently ignore errors adding 3D buildings
    }
  }

  /// Create markers on the map from complaint data
  Future<MarkerCreationResult> createMarkers(List<Complaint> complaints) async {
    if (!isInitialized || complaints.isEmpty) {
      return MarkerCreationResult.empty();
    }

    try {
      // Load marker image
      final ByteData bytes = await rootBundle.load('assets/map-point.png');
      final Uint8List imageData = bytes.buffer.asUint8List();

      // Create annotation manager if needed
      _pointAnnotationManager ??= await _mapboxMap!.annotations.createPointAnnotationManager();

      // Clear existing markers
      await _pointAnnotationManager!.deleteAll();

      // Prepare marker data
      final List<mapbox.PointAnnotationOptions> options = [];
      final List<mapbox.Position> coordinates = [];
      final Map<int, String> optionIndexToComplaintId = {};

      for (int i = 0; i < complaints.length; i++) {
        final complaint = complaints[i];
        final double latitude = complaint.latitude;
        final double longitude = complaint.longitude;
        final String complaintId = complaint.id;

        if (latitude != 0.0 && longitude != 0.0 && complaintId.isNotEmpty) {
          final position = mapbox.Position(longitude, latitude);
          options.add(mapbox.PointAnnotationOptions(
            geometry: mapbox.Point(coordinates: position),
            image: imageData,
            iconSize: _initialIconSize,
          ));
          coordinates.add(position);
          optionIndexToComplaintId[options.length - 1] = complaintId;
        }
      }

      if (options.isEmpty) {
        return MarkerCreationResult.empty();
      }

      // Create markers
      final List<mapbox.PointAnnotation?> createdAnnotationsNullable = 
          await _pointAnnotationManager!.createMulti(options);
      final List<mapbox.PointAnnotation> createdAnnotations = 
          createdAnnotationsNullable.whereType<mapbox.PointAnnotation>().toList();

      // Build annotation ID mapping
      final Map<String, String> annotationIdToComplaintId = {};
      for (int i = 0; i < createdAnnotations.length; i++) {
        final annotation = createdAnnotations[i];
        int originalOptionIndex = -1;
        int currentNonNullIndex = -1;
        
        for (int j = 0; j < createdAnnotationsNullable.length; j++) {
          if (createdAnnotationsNullable[j] != null) {
            currentNonNullIndex++;
            if (currentNonNullIndex == i) {
              originalOptionIndex = j;
              break;
            }
          }
        }

        if (originalOptionIndex != -1 && optionIndexToComplaintId.containsKey(originalOptionIndex)) {
          final complaintId = optionIndexToComplaintId[originalOptionIndex]!;
          annotationIdToComplaintId[annotation.id] = complaintId;
        }
      }

      return MarkerCreationResult(
        coordinates: coordinates,
        annotations: createdAnnotations,
        annotationMapping: annotationIdToComplaintId,
      );
    } catch (e) {
      return MarkerCreationResult.empty();
    }
  }

  /// Add click listener for markers
  void addMarkerClickListener(Function(mapbox.PointAnnotation) onTap) {
    if (_pointAnnotationManager == null) return;

    try {
      _pointAnnotationManager!.addOnPointAnnotationClickListener(
        PointAnnotationClickListener(onTap: onTap)
      );
    } catch (e) {
      // Silently ignore if adding listener fails
    }
  }

  /// Update marker sizes based on zoom level
  Future<void> updateMarkerSizes(List<mapbox.PointAnnotation> annotations, double zoom, {bool forceUpdate = false}) async {
    if (!isInitialized || _pointAnnotationManager == null || annotations.isEmpty) return;

    final newSize = _calculateIconSize(zoom);
    final currentSize = annotations.first.iconSize ?? _initialIconSize;
    
    if (!forceUpdate && (newSize - currentSize).abs() < 0.1) return;

    try {
      final updatedAnnotations = <mapbox.PointAnnotation>[];
      
      for (var annotation in annotations) {
        if ((annotation.iconSize ?? _initialIconSize - newSize).abs() > 0.05) {
          updatedAnnotations.add(mapbox.PointAnnotation(
            id: annotation.id,
            geometry: annotation.geometry,
            image: annotation.image,
            iconSize: newSize,
            iconOffset: annotation.iconOffset,
            iconAnchor: annotation.iconAnchor,
            iconOpacity: annotation.iconOpacity,
            iconColor: annotation.iconColor,
          ));
        }
      }

      if (updatedAnnotations.isNotEmpty) {
        for (int i = 0; i < updatedAnnotations.length; i++) {
          await _pointAnnotationManager?.update(updatedAnnotations[i]);
          if (i < updatedAnnotations.length - 1) {
            await Future.delayed(const Duration(milliseconds: 5));
          }
        }
      }
    } catch (e) {
      // Silently ignore annotation size update errors
    }
  }

  /// Calculate icon size based on zoom level
  double _calculateIconSize(double zoom) {
    const minZoom = 10.0;
    const maxZoom = 18.0;
    const minSize = 0.3;
    const maxSize = 1.0;

    if (zoom <= minZoom) return minSize;
    if (zoom >= maxZoom) return maxSize;

    final double zoomRatio = (zoom - minZoom) / (maxZoom - minZoom);
    return minSize + (maxSize - minSize) * zoomRatio;
  }

  /// Camera control methods
  Future<void> zoomIn() async {
    if (!isInitialized) return;
    
    try {
      final currentCamera = await _mapboxMap!.getCameraState();
      await _mapboxMap!.flyTo(
        mapbox.CameraOptions(
          zoom: currentCamera.zoom + _zoomIncrement,
          center: currentCamera.center,
          bearing: currentCamera.bearing,
          pitch: min(_maxPitch, currentCamera.pitch + _pitchIncrement),
        ),
        mapbox.MapAnimationOptions(duration: _animationDurationMs),
      );
    } catch (e) {
      // Silently ignore zoom errors
    }
  }

  Future<void> zoomOut() async {
    if (!isInitialized) return;
    
    try {
      final currentCamera = await _mapboxMap!.getCameraState();
      await _mapboxMap!.flyTo(
        mapbox.CameraOptions(
          zoom: max(0, currentCamera.zoom - _zoomIncrement),
          center: currentCamera.center,
          bearing: currentCamera.bearing,
          pitch: max(0.0, currentCamera.pitch - _pitchIncrement),
        ),
        mapbox.MapAnimationOptions(duration: _animationDurationMs),
      );
    } catch (e) {
      // Silently ignore zoom errors
    }
  }

  Future<void> rotateLeft() async {
    if (!isInitialized) return;
    
    try {
      final currentCamera = await _mapboxMap!.getCameraState();
      await _mapboxMap!.flyTo(
        mapbox.CameraOptions(
          bearing: currentCamera.bearing - _bearingIncrement,
          center: currentCamera.center,
          zoom: currentCamera.zoom,
          pitch: currentCamera.pitch,
        ),
        mapbox.MapAnimationOptions(duration: 800),
      );
    } catch (e) {
      // Silently ignore rotation errors
    }
  }

  Future<void> rotateRight() async {
    if (!isInitialized) return;
    
    try {
      final currentCamera = await _mapboxMap!.getCameraState();
      await _mapboxMap!.flyTo(
        mapbox.CameraOptions(
          bearing: currentCamera.bearing + _bearingIncrement,
          center: currentCamera.center,
          zoom: currentCamera.zoom,
          pitch: currentCamera.pitch,
        ),
        mapbox.MapAnimationOptions(duration: 800),
      );
    } catch (e) {
      // Silently ignore rotation errors
    }
  }

  Future<void> increasePitch() async {
    if (!isInitialized) return;
    
    try {
      final currentCamera = await _mapboxMap!.getCameraState();
      final currentPitch = currentCamera.pitch;
      const midPitch = 35.0;

      final targetPitch = (currentPitch < midPitch - 1.0) ? midPitch : _maxPitch;
      if ((targetPitch - currentPitch).abs() < 0.1) return;

      await _mapboxMap!.flyTo(
        mapbox.CameraOptions(
          pitch: targetPitch,
          center: currentCamera.center,
          zoom: currentCamera.zoom,
          bearing: currentCamera.bearing,
        ),
        mapbox.MapAnimationOptions(duration: 800),
      );
    } catch (e) {
      // Silently ignore pitch errors
    }
  }

  Future<void> decreasePitch() async {
    if (!isInitialized) return;
    
    try {
      final currentCamera = await _mapboxMap!.getCameraState();
      final currentPitch = currentCamera.pitch;
      const midPitch = 35.0;
      const minPitch = 0.0;

      final targetPitch = (currentPitch > midPitch + 1.0) ? midPitch : minPitch;
      if ((targetPitch - currentPitch).abs() < 0.1) return;

      await _mapboxMap!.flyTo(
        mapbox.CameraOptions(
          pitch: targetPitch,
          center: currentCamera.center,
          zoom: currentCamera.zoom,
          bearing: currentCamera.bearing,
        ),
        mapbox.MapAnimationOptions(duration: 800),
      );
    } catch (e) {
      // Silently ignore pitch errors
    }
  }

  /// Fly to a specific coordinate
  Future<void> flyToCoordinate(mapbox.Position coordinate) async {
    if (!isInitialized) return;

    try {
      await _mapboxMap!.flyTo(
        mapbox.CameraOptions(
          center: mapbox.Point(coordinates: coordinate),
          zoom: 18.5,
          pitch: 70.0,
          bearing: 45.0,
        ),
        mapbox.MapAnimationOptions(duration: 3000),
      );
    } catch (e) {
      // Silently ignore fly-to errors
    }
  }

  /// Reset camera to initial view or fit all markers
  Future<void> resetCameraView(List<mapbox.Position> coordinates, BuildContext? context, {bool isBottomSheetVisible = false}) async {
    if (!isInitialized) return;

    if (coordinates.isEmpty) {
      try {
        await _mapboxMap!.flyTo(_initialCameraOptions, mapbox.MapAnimationOptions(duration: 1500));
      } catch (e) {
        // Silently ignore camera reset errors
      }
      return;
    }

    try {
      List<mapbox.Point> points = coordinates
          .map((pos) => mapbox.Point(coordinates: pos))
          .toList();

      mapbox.ScreenBox? screenBox;
      if (context != null) {
        final screenSize = MediaQuery.of(context).size;
        final screenPadding = MediaQuery.of(context).padding;
        const appBarHeight = kToolbarHeight;
        final bottomSheetHeight = isBottomSheetVisible ? 200.0 : 0.0;

        screenBox = mapbox.ScreenBox(
          min: mapbox.ScreenCoordinate(x: 0, y: screenPadding.top + appBarHeight),
          max: mapbox.ScreenCoordinate(x: screenSize.width, y: screenSize.height - bottomSheetHeight),
        );
      }

      mapbox.CameraOptions cameraOptions;
      if (screenBox != null) {
        cameraOptions = await _mapboxMap!.cameraForCoordinatesCameraOptions(
          points,
          mapbox.CameraOptions(
            padding: mapbox.MbxEdgeInsets(top: 40.0, left: 40.0, bottom: 40.0, right: 40.0),
            bearing: 0.0,
            pitch: 0.0,
          ),
          screenBox,
        );
      } else {
        cameraOptions = await _mapboxMap!.cameraForCoordinatesCameraOptions(
          points,
          mapbox.CameraOptions(
            padding: mapbox.MbxEdgeInsets(top: 40.0, left: 40.0, bottom: 40.0, right: 40.0),
            bearing: 0.0,
            pitch: 0.0,
          ),
          mapbox.ScreenBox(
            min: mapbox.ScreenCoordinate(x: 0, y: 0),
            max: mapbox.ScreenCoordinate(x: 1000, y: 1000),
          ),
        );
      }

      await _mapboxMap!.flyTo(cameraOptions, mapbox.MapAnimationOptions(duration: 1500));
    } catch (e) {
      // Fallback to default view on error
      await _mapboxMap!.flyTo(_initialCameraOptions, mapbox.MapAnimationOptions(duration: 1500));
    }
  }

  /// Get current camera state
  Future<mapbox.CameraState?> getCameraState() async {
    if (!isInitialized) return null;
    
    try {
      return await _mapboxMap!.getCameraState();
    } catch (e) {
      return null;
    }
  }

  /// Setup camera change listener with debouncing
  void setupCameraChangeListener(Function(double zoom) onZoomChange) {
    // Cancel existing timer
    _debounceTimer?.cancel();
    
    // Set up debounced camera change handler
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (_isDisposed || !isInitialized) return;

      try {
        final cameraState = await getCameraState();
        if (cameraState != null) {
          onZoomChange(cameraState.zoom);
        }
      } catch (e) {
        // Silently ignore camera change errors
      }
    });
  }

  /// Dispose resources
  void dispose() {
    if (_isDisposed) return;
    
    // Cancel any ongoing timers
    _debounceTimer?.cancel();
    _debounceTimer = null;
    
    // Set disposal flag to prevent further operations
    _isDisposed = true;
    
    // Clean up annotation manager first
    final manager = _pointAnnotationManager;
    if (manager != null) {
      try {
        // Use Future.microtask to avoid blocking the disposal
        Future.microtask(() async {
          try {
            await manager.deleteAll();
            _mapboxMap?.annotations.removeAnnotationManager(manager);
          } catch (e) {
            // Silently ignore cleanup errors
          }
        });
      } catch (e) {
        // Silently ignore cleanup errors
      }
      _pointAnnotationManager = null;
    }

    // Safely dispose of the map instance with delayed cleanup
    final map = _mapboxMap;
    _mapboxMap = null;
    
    if (map != null) {
      // Use a longer delay to ensure all operations complete
      Future.delayed(const Duration(seconds: 3), () {
        try {
          map.dispose();
        } catch (e) {
          // Silently ignore disposal errors - this is expected in some cases
        }
      });
    }
  }
}

/// Result class for marker creation operations
class MarkerCreationResult {
  final List<mapbox.Position> coordinates;
  final List<mapbox.PointAnnotation> annotations;
  final Map<String, String> annotationMapping;

  const MarkerCreationResult({
    required this.coordinates,
    required this.annotations,
    required this.annotationMapping,
  });

  factory MarkerCreationResult.empty() {
    return const MarkerCreationResult(
      coordinates: [],
      annotations: [],
      annotationMapping: {},
    );
  }

  bool get isEmpty => coordinates.isEmpty;
  bool get isNotEmpty => coordinates.isNotEmpty;
}

/// Custom click listener class for point annotations
class PointAnnotationClickListener extends mapbox.OnPointAnnotationClickListener {
  final Function(mapbox.PointAnnotation) onTap;
  
  PointAnnotationClickListener({required this.onTap});
  
  @override
  bool onPointAnnotationClick(mapbox.PointAnnotation annotation) {
    onTap(annotation);
    return true;
  }
}
