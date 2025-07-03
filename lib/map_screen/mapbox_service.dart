import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import '../models.dart';
import '../utils/logger.dart';
import '../utils/map_debug_helper.dart';
import 'map_icon_service.dart';

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
    
    // Initialize icon service if not already done
    _ensureIconServiceInitialized();
  }
  
  /// Ensure MapIconService is initialized
  Future<void> _ensureIconServiceInitialized() async {
    try {
      await MapIconService.instance.initialize();
    } catch (e) {
      AppLogger.w('[MapboxService] Icon service initialization failed, will use fallback: $e');
    }
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
      // Get cached icon data instead of loading from assets every time
      Uint8List imageData;
      try {
        imageData = MapIconService.instance.originalIcon;
        AppLogger.d('[MapboxService] Using cached icon data');
      } catch (e) {
        // Fallback to direct loading if icon service fails
        AppLogger.w('[MapboxService] Icon service unavailable, using fallback loading: $e');
        final ByteData bytes = await rootBundle.load('assets/map-point.png');
        imageData = bytes.buffer.asUint8List();
      }

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

  /// Update marker sizes based on zoom level with optimized batch processing
  Future<BatchUpdateResult> updateMarkerSizes(List<mapbox.PointAnnotation> annotations, double zoom, {bool forceUpdate = false}) async {
    final startTime = DateTime.now();
    
    if (!isInitialized || _pointAnnotationManager == null || annotations.isEmpty) {
      return BatchUpdateResult(
        totalMarkers: 0,
        updatedMarkers: 0,
        processingTime: Duration.zero,
        sizeGroups: {},
      );
    }

    try {
      // Use optimized size calculation from MapIconService
      final iconService = MapIconService.instance;
      final newSize = iconService.getSizeForZoom(zoom);
      
      // Get optimized icon data for the new size
      Uint8List? optimizedIconData;
      try {
        optimizedIconData = iconService.getIconForSize(newSize);
      } catch (e) {
        AppLogger.w('[MapboxService] Could not get optimized icon, using existing data: $e');
      }
      
      // Group annotations that need updates using the icon service's intelligent grouping
      final currentSize = annotations.isNotEmpty ? (annotations.first.iconSize ?? _initialIconSize) : _initialIconSize;
      
      if (!forceUpdate && !iconService.shouldUpdateSize(currentSize, newSize)) {
        return BatchUpdateResult(
          totalMarkers: annotations.length,
          updatedMarkers: 0,
          processingTime: DateTime.now().difference(startTime),
          sizeGroups: {},
        );
      }

      // Create optimized batch updates
      final updatedAnnotations = <mapbox.PointAnnotation>[];
      final sizeGroups = <double, int>{};
      
      for (var annotation in annotations) {
        final annotationCurrentSize = annotation.iconSize ?? _initialIconSize;
        
        if (forceUpdate || iconService.shouldUpdateSize(annotationCurrentSize, newSize)) {
          updatedAnnotations.add(mapbox.PointAnnotation(
            id: annotation.id,
            geometry: annotation.geometry,
            image: optimizedIconData ?? annotation.image,
            iconSize: newSize,
            iconOffset: annotation.iconOffset,
            iconAnchor: annotation.iconAnchor,
            iconOpacity: annotation.iconOpacity,
            iconColor: annotation.iconColor,
          ));
          
          sizeGroups[newSize] = (sizeGroups[newSize] ?? 0) + 1;
        }
      }

      // Perform batch updates with optimized timing
      if (updatedAnnotations.isNotEmpty) {
        await _performBatchUpdate(updatedAnnotations);
      }
      
      final processingTime = DateTime.now().difference(startTime);
      final result = BatchUpdateResult(
        totalMarkers: annotations.length,
        updatedMarkers: updatedAnnotations.length,
        processingTime: processingTime,
        sizeGroups: sizeGroups,
      );
      
      if (updatedAnnotations.isNotEmpty) {
        AppLogger.d('[MapboxService] Batch update completed: $result');
      }
      
      return result;
      
    } catch (e) {
      AppLogger.e('[MapboxService] Error in batch marker update: $e');
      return BatchUpdateResult(
        totalMarkers: annotations.length,
        updatedMarkers: 0,
        processingTime: DateTime.now().difference(startTime),
        sizeGroups: {},
      );
    }
  }
  
  /// Perform optimized batch update with intelligent delays
  Future<void> _performBatchUpdate(List<mapbox.PointAnnotation> annotations) async {
    const int batchSize = 10; // Process in smaller batches
    const int delayBetweenBatches = 2; // Reduced delay
    
    for (int i = 0; i < annotations.length; i += batchSize) {
      final batchEnd = min(i + batchSize, annotations.length);
      final batch = annotations.sublist(i, batchEnd);
      
      // Process batch
      for (final annotation in batch) {
        await _pointAnnotationManager?.update(annotation);
      }
      
      // Add small delay between batches to prevent overwhelming the graphics pipeline
      if (batchEnd < annotations.length) {
        await Future.delayed(Duration(milliseconds: delayBetweenBatches));
      }
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

  /// Reset camera view to encompass all markers with enhanced error handling and fallback strategies
  Future<void> resetCameraView(
    List<mapbox.Position> coordinates, 
    BuildContext? context, {
    bool isBottomSheetVisible = false
  }) async {
    if (_isDisposed || !isInitialized) return;

    final startTime = DateTime.now();
    
    // Capture context availability before async operations to avoid BuildContext sync issues
    final hasContext = context != null;

    AppLogger.i('[MapboxService] Camera reset initiated for ${coordinates.length} coordinates');
    AppLogger.d('[MapboxService] Bottom sheet visible: $isBottomSheetVisible');

    // Validate coordinates
    final validationResult = _validateCoordinates(coordinates);
    if (!validationResult.isValid) {
      AppLogger.w('[MapboxService] ${validationResult.message}');
    }

    // If no coordinates provided, go to default view
    if (coordinates.isEmpty) {
      AppLogger.i('[MapboxService] No coordinates provided - using default view');
      try {
        await _mapboxMap!.flyTo(_initialCameraOptions, mapbox.MapAnimationOptions(duration: 1500));
        AppLogger.i('[MapboxService] Successfully moved to default view');
        
        // Log successful default view
        MapDebugHelper.logCameraOperation(
          operationType: 'resetCameraView_default_empty',
          coordinates: coordinates,
          context: hasContext ? context : null, // Only pass if we know it's safe
          isSuccess: true,
          additionalInfo: 'moved to default view for empty coordinates',
        );
      } catch (e) {
        AppLogger.e('[MapboxService] Failed to move to default view: $e');
        
        // Log failure
        MapDebugHelper.logCameraOperation(
          operationType: 'resetCameraView_default_empty',
          coordinates: coordinates,
          context: hasContext ? context : null,
          isSuccess: false,
          errorMessage: e.toString(),
        );
      }
      return;
    }

    try {
      List<mapbox.Point> points = coordinates
          .map((pos) => mapbox.Point(coordinates: pos))
          .toList();

      AppLogger.d('[MapboxService] Converted ${points.length} coordinates to points');

      mapbox.ScreenBox screenBox;
      mapbox.MbxEdgeInsets padding;

      // Calculate screen dimensions and padding based on context availability
      if (context != null) {
        final screenCalculation = _calculateScreenDimensions(context, isBottomSheetVisible);
        screenBox = screenCalculation.screenBox;
        padding = screenCalculation.padding;
        
        AppLogger.d('[MapboxService] Screen dimensions calculated from context');
        AppLogger.d('[MapboxService] Screen size: ${screenCalculation.screenSize.width}x${screenCalculation.screenSize.height}');
        AppLogger.d('[MapboxService] Padding: T:${padding.top}, L:${padding.left}, B:${padding.bottom}, R:${padding.right}');
      } else {
        final fallbackCalculation = _calculateFallbackDimensions(isBottomSheetVisible);
        screenBox = fallbackCalculation.screenBox;
        padding = fallbackCalculation.padding;
        
        AppLogger.w('[MapboxService] Using fallback screen dimensions');
        AppLogger.d('[MapboxService] Fallback padding: T:${padding.top}, L:${padding.left}, B:${padding.bottom}, R:${padding.right}');
      }

      // Calculate camera options to fit all coordinates with proper padding
      AppLogger.d('[MapboxService] Calculating camera options for coordinate bounds');
      mapbox.CameraOptions cameraOptions = await _mapboxMap!.cameraForCoordinatesCameraOptions(
        points,
        mapbox.CameraOptions(
          padding: padding,
          bearing: 0.0, // Reset bearing to north-up
          pitch: 0.0,   // Reset pitch to flat view for overview
        ),
        screenBox,
      );

      AppLogger.d('[MapboxService] Camera options calculated - Center: ${cameraOptions.center?.coordinates.lng}, ${cameraOptions.center?.coordinates.lat}');
      AppLogger.d('[MapboxService] Original zoom: ${cameraOptions.zoom}');

      // Enhanced zoom level adjustment for better marker visibility
      final zoomCalculation = _calculateOptimalZoom(coordinates, cameraOptions.zoom);
      AppLogger.d('[MapboxService] Zoom calculation: ${zoomCalculation.originalZoom} -> ${zoomCalculation.adjustedZoom} (${zoomCalculation.reason})');

      // Apply the camera movement with adjusted zoom
      AppLogger.i('[MapboxService] Applying camera movement with zoom ${zoomCalculation.adjustedZoom}');
      await _mapboxMap!.flyTo(
        mapbox.CameraOptions(
          center: cameraOptions.center,
          zoom: zoomCalculation.adjustedZoom,
          bearing: 0.0,
          pitch: 0.0,
        ),
        mapbox.MapAnimationOptions(duration: 1500),
      );

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      AppLogger.i('[MapboxService] Camera reset completed successfully in ${duration.inMilliseconds}ms');

      // Log successful operation with performance metrics
      MapDebugHelper.logCameraOperation(
        operationType: 'resetCameraView',
        coordinates: coordinates,
        context: null, // Don't pass context after async gap
        isSuccess: true,
        additionalInfo: 'duration: ${duration.inMilliseconds}ms, finalZoom: ${zoomCalculation.adjustedZoom}',
      );

      MapDebugHelper.logPerformanceMetrics(
        operation: 'resetCameraView',
        duration: duration,
        coordinateCount: coordinates.length,
        finalZoom: zoomCalculation.adjustedZoom,
      );

    } catch (e) {
      AppLogger.e('[MapboxService] Camera reset failed: $e');
      
      // Log primary failure
      MapDebugHelper.logCameraOperation(
        operationType: 'resetCameraView',
        coordinates: coordinates,
        context: null, // Don't pass context after async gap
        isSuccess: false,
        errorMessage: e.toString(),
      );
      
      // Enhanced fallback handling
      try {
        AppLogger.i('[MapboxService] Attempting fallback camera reset');
        // If camera calculation fails, try a simple bounds-based approach
        if (coordinates.isNotEmpty) {
          final bounds = _calculateSimpleBounds(coordinates);
          AppLogger.d('[MapboxService] Using simple bounds: center(${bounds.center.lng}, ${bounds.center.lat}), zoom: ${bounds.suggestedZoom}');
          
          await _mapboxMap!.flyTo(
            mapbox.CameraOptions(
              center: mapbox.Point(coordinates: bounds.center),
              zoom: bounds.suggestedZoom,
              bearing: 0.0,
              pitch: 0.0,
            ),
            mapbox.MapAnimationOptions(duration: 1500),
          );
          AppLogger.i('[MapboxService] Fallback camera reset successful');
          
          // Log successful fallback
          MapDebugHelper.logCameraOperation(
            operationType: 'resetCameraView_fallback',
            coordinates: coordinates,
            context: null, // Don't pass context after async gap
            isSuccess: true,
            additionalInfo: 'fallback successful with simple bounds',
          );
        } else {
          // Final fallback to default view
          AppLogger.i('[MapboxService] Using final fallback to default view');
          await _mapboxMap!.flyTo(_initialCameraOptions, mapbox.MapAnimationOptions(duration: 1500));
          
          // Log default fallback success
          MapDebugHelper.logCameraOperation(
            operationType: 'resetCameraView_default',
            coordinates: coordinates,
            context: null, // Don't pass context after async gap
            isSuccess: true,
            additionalInfo: 'fallback to default view successful',
          );
        }
      } catch (fallbackError) {
        AppLogger.e('[MapboxService] All fallback attempts failed: $fallbackError');
        
        // Log fallback failure
        MapDebugHelper.logCameraOperation(
          operationType: 'resetCameraView_fallback',
          coordinates: coordinates,
          context: null, // Don't pass context after async gap
          isSuccess: false,
          errorMessage: fallbackError.toString(),
        );
        
        // If everything fails, just go to default location
        try {
          await _mapboxMap!.flyTo(_initialCameraOptions, mapbox.MapAnimationOptions(duration: 1500));
          AppLogger.i('[MapboxService] Emergency fallback to default successful');
          
          // Log emergency fallback success
          MapDebugHelper.logCameraOperation(
            operationType: 'resetCameraView_emergency',
            coordinates: coordinates,
            context: null, // Don't pass context after async gap
            isSuccess: true,
            additionalInfo: 'emergency fallback successful',
          );
        } catch (emergencyError) {
          AppLogger.e('[MapboxService] Emergency fallback failed: $emergencyError');
          
          // Log complete failure
          MapDebugHelper.logCameraOperation(
            operationType: 'resetCameraView_emergency',
            coordinates: coordinates,
            context: null, // Don't pass context after async gap
            isSuccess: false,
            errorMessage: emergencyError.toString(),
          );
        }
      }
    }
  }

  /// Calculate simple bounds for coordinates when advanced calculation fails
  SimpleBounds _calculateSimpleBounds(List<mapbox.Position> coordinates) {
    if (coordinates.isEmpty) {
      return SimpleBounds(
        center: mapbox.Position(147.1803, -9.4438), // Port Moresby
        suggestedZoom: 12.0,
      );
    }

    double minLat = coordinates.first.lat.toDouble();
    double maxLat = coordinates.first.lat.toDouble();
    double minLng = coordinates.first.lng.toDouble();
    double maxLng = coordinates.first.lng.toDouble();

    for (final coord in coordinates) {
      minLat = minLat < coord.lat ? minLat : coord.lat.toDouble();
      maxLat = maxLat > coord.lat ? maxLat : coord.lat.toDouble();
      minLng = minLng < coord.lng ? minLng : coord.lng.toDouble();
      maxLng = maxLng > coord.lng ? maxLng : coord.lng.toDouble();
    }

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;
    
    // Enhanced zoom calculation based on bounds and marker count
    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
    
    // Improved zoom calculation that accounts for padding and marker count
    double suggestedZoom;
    
    if (coordinates.length == 1) {
      // Single marker: comfortable zoom level
      suggestedZoom = 13.0;
    } else if (maxDiff > 0.2) {
      // Very spread out markers
      suggestedZoom = 8.0;
    } else if (maxDiff > 0.1) {
      // Moderately spread out markers
      suggestedZoom = 9.0;
    } else if (maxDiff > 0.05) {
      // Somewhat close markers
      suggestedZoom = 11.0;
    } else if (maxDiff > 0.01) {
      // Close markers
      suggestedZoom = 13.0;
    } else {
      // Very close markers
      suggestedZoom = 14.0;
    }
    
    // Adjust zoom based on marker count for better visibility with enhanced padding
    if (coordinates.length > 20) {
      suggestedZoom = suggestedZoom - 1.0; // Zoom out more for many markers
    } else if (coordinates.length > 10) {
      suggestedZoom = suggestedZoom - 0.5; // Zoom out slightly for moderate markers
    }
    
    // Account for enhanced padding by reducing zoom slightly
    suggestedZoom = suggestedZoom - 0.5;
    
    // Ensure reasonable bounds
    if (suggestedZoom < 6.0) suggestedZoom = 6.0;
    if (suggestedZoom > 15.0) suggestedZoom = 15.0;

    return SimpleBounds(
      center: mapbox.Position(centerLng, centerLat),
      suggestedZoom: suggestedZoom,
    );
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

  // === VALIDATION AND DEBUG METHODS ===

  /// Validate coordinates for camera reset operations
  CoordinateValidationResult _validateCoordinates(List<mapbox.Position> coordinates) {
    if (coordinates.isEmpty) {
      return CoordinateValidationResult(
        isValid: true,
        message: 'Empty coordinates list - will use default view',
      );
    }

    int invalidCount = 0;
    final List<String> issues = [];

    for (int i = 0; i < coordinates.length; i++) {
      final coord = coordinates[i];
      
      // Check latitude bounds
      if (coord.lat < -90 || coord.lat > 90) {
        issues.add('Coordinate $i: Invalid latitude ${coord.lat} (must be -90 to 90)');
        invalidCount++;
      }
      
      // Check longitude bounds
      if (coord.lng < -180 || coord.lng > 180) {
        issues.add('Coordinate $i: Invalid longitude ${coord.lng} (must be -180 to 180)');
        invalidCount++;
      }
      
      // Check for NaN or infinity
      if (coord.lat.isNaN || coord.lat.isInfinite) {
        issues.add('Coordinate $i: Latitude is NaN or infinite');
        invalidCount++;
      }
      
      if (coord.lng.isNaN || coord.lng.isInfinite) {
        issues.add('Coordinate $i: Longitude is NaN or infinite');
        invalidCount++;
      }
    }

    final isValid = invalidCount == 0;
    final message = isValid 
        ? 'All ${coordinates.length} coordinates are valid'
        : 'Found $invalidCount invalid coordinates: ${issues.join(', ')}';

    return CoordinateValidationResult(
      isValid: isValid,
      message: message,
      invalidCount: invalidCount,
      issues: issues,
    );
  }

  /// Calculate screen dimensions and padding from context
  ScreenCalculationResult _calculateScreenDimensions(BuildContext context, bool isBottomSheetVisible) {
    final screenSize = MediaQuery.of(context).size;
    final screenPadding = MediaQuery.of(context).padding;
    const appBarHeight = kToolbarHeight;
    final bottomSheetHeight = isBottomSheetVisible ? 200.0 : 0.0;

    final screenBox = mapbox.ScreenBox(
      min: mapbox.ScreenCoordinate(x: 0, y: screenPadding.top + appBarHeight),
      max: mapbox.ScreenCoordinate(x: screenSize.width, y: screenSize.height - bottomSheetHeight),
    );

    // Enhanced padding calculation for better marker visibility
    final horizontalPadding = screenSize.width * 0.12;
    final basePadding = screenSize.height * 0.08;
    
    final topPadding = screenPadding.top + appBarHeight + basePadding + 20.0;
    final bottomPadding = bottomSheetHeight + basePadding + 60.0;
    final leftPadding = horizontalPadding + 80.0;
    final rightPadding = horizontalPadding + 20.0;

    final padding = mapbox.MbxEdgeInsets(
      top: topPadding,
      left: leftPadding,
      bottom: bottomPadding,
      right: rightPadding,
    );

    return ScreenCalculationResult(
      screenSize: screenSize,
      screenBox: screenBox,
      padding: padding,
    );
  }

  /// Calculate fallback screen dimensions when context is unavailable
  ScreenCalculationResult _calculateFallbackDimensions(bool isBottomSheetVisible) {
    const fallbackWidth = 375.0;
    const fallbackHeight = 812.0;
    const fallbackStatusBarHeight = 44.0;
    const appBarHeight = kToolbarHeight;
    final bottomSheetHeight = isBottomSheetVisible ? 200.0 : 0.0;

    final screenBox = mapbox.ScreenBox(
      min: mapbox.ScreenCoordinate(x: 0, y: fallbackStatusBarHeight + appBarHeight),
      max: mapbox.ScreenCoordinate(x: fallbackWidth, y: fallbackHeight - bottomSheetHeight),
    );

    const baseFallbackPadding = 60.0;
    const topExtraPadding = 80.0;
    const bottomExtraPadding = 80.0;
    const leftExtraPadding = 100.0;
    const rightExtraPadding = 40.0;

    final padding = mapbox.MbxEdgeInsets(
      top: baseFallbackPadding + topExtraPadding + appBarHeight,
      left: baseFallbackPadding + leftExtraPadding,
      bottom: baseFallbackPadding + bottomExtraPadding + bottomSheetHeight,
      right: baseFallbackPadding + rightExtraPadding,
    );

    return ScreenCalculationResult(
      screenSize: const Size(fallbackWidth, fallbackHeight),
      screenBox: screenBox,
      padding: padding,
    );
  }

  /// Calculate optimal zoom level with detailed reasoning
  ZoomCalculationResult _calculateOptimalZoom(List<mapbox.Position> coordinates, double? originalZoom) {
    double adjustedZoom;
    String reason;
    
    if (originalZoom != null) {
      final coordCount = coordinates.length;
      
      if (coordCount == 1) {
        adjustedZoom = 14.0;
        reason = 'Single marker: fixed zoom 14.0';
      } else if (coordCount <= 3) {
        adjustedZoom = originalZoom > 16.0 ? 16.0 : (originalZoom < 10.0 ? 10.0 : originalZoom);
        reason = 'Few markers ($coordCount): clamped to 10.0-16.0';
      } else if (coordCount <= 10) {
        adjustedZoom = originalZoom > 14.0 ? 14.0 : (originalZoom < 8.0 ? 8.0 : originalZoom);
        reason = 'Medium markers ($coordCount): clamped to 8.0-14.0';
      } else {
        adjustedZoom = originalZoom > 12.0 ? 12.0 : (originalZoom < 6.0 ? 6.0 : originalZoom);
        reason = 'Many markers ($coordCount): clamped to 6.0-12.0';
      }
      
      // Additional zoom adjustment to account for increased padding
      adjustedZoom = adjustedZoom - 0.5;
      reason += ', -0.5 for padding compensation';
      
      // Ensure we stay within reasonable bounds
      if (adjustedZoom < 6.0) {
        adjustedZoom = 6.0;
        reason += ', minimum clamped to 6.0';
      }
      if (adjustedZoom > 16.0) {
        adjustedZoom = 16.0;
        reason += ', maximum clamped to 16.0';
      }
    } else {
      // Fallback zoom based on marker count
      final coordCount = coordinates.length;
      if (coordCount == 1) {
        adjustedZoom = 14.0;
        reason = 'Fallback: single marker zoom 14.0';
      } else if (coordCount <= 5) {
        adjustedZoom = 12.0;
        reason = 'Fallback: few markers zoom 12.0';
      } else {
        adjustedZoom = 10.0;
        reason = 'Fallback: many markers zoom 10.0';
      }
    }

    return ZoomCalculationResult(
      originalZoom: originalZoom ?? 0.0,
      adjustedZoom: adjustedZoom,
      reason: reason,
    );
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

/// Simple bounds calculation result for fallback scenarios
class SimpleBounds {
  final mapbox.Position center;
  final double suggestedZoom;

  const SimpleBounds({
    required this.center,
    required this.suggestedZoom,
  });
}

/// Coordinate validation result for debugging
class CoordinateValidationResult {
  final bool isValid;
  final String message;
  final int invalidCount;
  final List<String> issues;

  const CoordinateValidationResult({
    required this.isValid,
    required this.message,
    this.invalidCount = 0,
    this.issues = const [],
  });
}

/// Screen calculation result for debugging
class ScreenCalculationResult {
  final Size screenSize;
  final mapbox.ScreenBox screenBox;
  final mapbox.MbxEdgeInsets padding;

  const ScreenCalculationResult({
    required this.screenSize,
    required this.screenBox,
    required this.padding,
  });
}

/// Zoom calculation result for debugging
class ZoomCalculationResult {
  final double originalZoom;
  final double adjustedZoom;
  final String reason;

  const ZoomCalculationResult({
    required this.originalZoom,
    required this.adjustedZoom,
    required this.reason,
  });
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

