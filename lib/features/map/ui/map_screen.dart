import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import '../widgets/complaint_carousel.dart';
import '../../utils/app_logger.dart';
import '../state/map_provider.dart'; // Import MapProvider
import 'package:provider/provider.dart'; // Import Provider
import '../widgets/complaint_details_sheet.dart';
import '../widgets/map_controls.dart';
import '../widgets/safe_mapbox_widget.dart';
import '../../utils/size_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ======== HELPER CLASS FOR ANNOTATION CLICKS ========
class _AnnotationClickListener extends mapbox.OnPointAnnotationClickListener {
  final void Function(mapbox.PointAnnotation) onTap;

  _AnnotationClickListener({required this.onTap});

  @override
  void onPointAnnotationClick(mapbox.PointAnnotation annotation) {
    onTap(annotation);
  }
}

// Helper class to hold data prepared for annotations in a separate isolate.
class _PreparedAnnotationData {
  final List<mapbox.PointAnnotationOptions> options;
  final List<mapbox.Position> coordinates;
  final Map<int, String> optionIndexToComplaintId;
  final Map<String, int> complaintIdToDataIndex;

  _PreparedAnnotationData({
    required this.options,
    required this.coordinates,
    required this.optionIndexToComplaintId,
    required this.complaintIdToDataIndex,
  });
}

// Top-level function to be executed in a separate isolate via compute().
_PreparedAnnotationData _prepareAnnotationOptions(Map<String, dynamic> args) {
  final List<Map<String, dynamic>> complaintsData = args['complaints'];
  final Uint8List imageData = args['imageData'];
  final double initialIconSize = args['initialIconSize'];

  final List<mapbox.PointAnnotationOptions> options = [];
  final List<mapbox.Position> coordinates = [];
  final Map<int, String> optionIndexToComplaintId = {};
  final Map<String, int> complaintIdToDataIndex = {};

  for (int i = 0; i < complaintsData.length; i++) {
    final complaint = complaintsData[i];
    final dynamic latValue = complaint['latitude'];
    final dynamic lonValue = complaint['longitude'];
    final dynamic complaintIdValue = complaint['id'];

    double? latitude;
    double? longitude;
    String? complaintId;

    if (latValue is num) {
      latitude = latValue.toDouble();
    } else if (latValue is String) {
      latitude = double.tryParse(latValue);
    }

    if (lonValue is num) {
      longitude = lonValue.toDouble();
    } else if (lonValue is String) {
      longitude = double.tryParse(lonValue);
    }

    if (complaintIdValue != null) {
      complaintId = complaintIdValue.toString();
    }

    if (latitude != null &&
        longitude != null &&
        complaintId != null &&
        complaintId.isNotEmpty) {
      final position = mapbox.Position(longitude, latitude);
      options.add(mapbox.PointAnnotationOptions(
        geometry: mapbox.Point(coordinates: position).toJson(),
        image: imageData,
        iconSize: initialIconSize,
      ));
      coordinates.add(position);
      optionIndexToComplaintId[options.length - 1] = complaintId;
      complaintIdToDataIndex[complaintId] =
          i; // Map complaint ID to its index in the original data list
    }
  }

  return _PreparedAnnotationData(
    options: options,
    coordinates: coordinates,
    optionIndexToComplaintId: optionIndexToComplaintId,
    complaintIdToDataIndex: complaintIdToDataIndex,
  );
}

// --- Map Screen Widget ---
class MapScreen extends StatefulWidget {
  final VoidCallback onBack;
  const MapScreen({super.key, required this.onBack});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  mapbox.MapboxMap? mapboxMap; // Keep local map controller instance
  bool _isDisposed = false;
  mapbox.PointAnnotationManager? _pointAnnotationManager; // Keep local annotation manager

  // Removed state variables now in MapProvider:
  // List<Map<String, dynamic>> _complaintsData = [];
  // bool _isLoadingComplaints = true;
  // List<mapbox.Position> _complaintCoordinates = [];
  // int? _selectedComplaintIndex;
  // List<mapbox.PointAnnotation> _currentAnnotations = [];
  // double _currentZoom = 12.0; // Will get from provider
  // PageController? _pageController; // Will get from provider
  // Map<String, String> _annotationIdToComplaintId = {};
  // Map<String, int> _complaintIdToDataIndex = {};

  int _currentMarkerIndex = -1; // Still local if it only drives map flying, not general UI state.
                                  // Or move to provider if other widgets need to know the "map's current marker".
                                  // For now, keeping it local as it's tied to _flyToCoordinate.

  Timer? _debounceTimer; // UI-specific timer, keep local
  static const double _initialIconSize = 0.5; // Constant, keep local or move to provider if configurable

  final Set<String> _bouncingAnnotationIds = {}; // UI-specific animation state, keep local

  static const double _zoomIncrement = 1.0;
  static const double _bearingIncrement = 30.0;
  static const double _pitchIncrement = 15.0;
  static const double _maxPitch = 70.0;

  static final mapbox.CameraOptions _initialCameraOptions = mapbox.CameraOptions(
    center:
        mapbox.Point(coordinates: mapbox.Position(147.1803, -9.4438)).toJson(),
    zoom: 7.0,
    pitch: 0.0,
    bearing: 0.0,
  );

  @override
  void initState() {
    super.initState();
    // Accessing provider here is fine for one-off actions, but listen:false for events.
    // However, initPageController should ideally be called when the provider is created or first used.
    // For now, let's assume MapScreen is the primary user of pageController.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) { // Ensure mounted before accessing context.read
          context.read<MapProvider>().initPageController();
      }
    });
    // _fetchComplaintCoordinates will be called from _onStyleLoadedCallback
    // which itself is called after map is ready.
  }

  @override
  void dispose() {
    appLogger.info("Disposing MapScreen");
    _debounceTimer?.cancel();
    // _pageController?.dispose(); // PageController is now managed by MapProvider
    if (mounted) { // Check mounted before accessing context
      context.read<MapProvider>().disposePageController();
    }
    _isDisposed = true;

    final manager = _pointAnnotationManager;
    if (manager != null) {
      try {
        mapboxMap?.annotations.removeAnnotationManager(manager);
        appLogger.fine("PointAnnotationManager cleaned up.");
      } catch (e, s) {
        appLogger.warning("Error cleaning up PointAnnotationManager", e, s);
      }
      _pointAnnotationManager = null;
    }

    final map = mapboxMap;
    mapboxMap = null;

    try {
      if (map != null) {
        map.dispose();
        appLogger.fine("MapboxMap successfully disposed");
      } else {
        appLogger.fine("No MapboxMap instance to dispose");
      }
    } catch (e, s) {
      appLogger.warning("Error during MapboxMap disposal", e, s);
    }

    super.dispose();
    appLogger.info("MapScreen fully disposed");
  }

  void _cancelMapOperations() {
    final map = mapboxMap;
    if (map != null && !_isDisposed) {
      try {
        map.style.getStyleURI();
        appLogger.fine("Map operations interrupted before navigation");
      } catch (e, s) {
        appLogger.warning("Error interrupting map operations", e, s);
      }
    }
  }

  void _prepareForNavigation() {
    if (_isDisposed) return;
    _cancelMapOperations();
    appLogger.fine("Map prepared for navigation");
  }

  void _onMapCreated(mapbox.MapboxMap mapboxMap) async {
    if (_isDisposed || !mounted) return;

    appLogger.info("Map created callback received.");
    this.mapboxMap = mapboxMap;

    try {
      if (_isDisposed || !mounted) return;
      mapboxMap.gestures.updateSettings(mapbox.GesturesSettings(
        rotateEnabled: true,
        pitchEnabled: true,
        scrollEnabled: true,
        doubleTapToZoomInEnabled: true,
        doubleTouchToZoomOutEnabled: true,
        quickZoomEnabled: true,
      ));
      appLogger.fine("Gesture settings updated.");
    } catch (e, s) {
      if (mounted) {
        appLogger.warning("Error updating gesture settings", e, s);
      }
    }
  }

  void _onStyleLoadedCallback(mapbox.StyleLoadedEventData data) async {
    if (_isDisposed || !mounted || mapboxMap == null) return;

    appLogger.info("Style loaded callback received.");

    try {
      appLogger.fine("Configuring ornaments via map controller...");
      await mapboxMap!.scaleBar.updateSettings(mapbox.ScaleBarSettings(
        position: mapbox.OrnamentPosition.BOTTOM_LEFT,
        marginLeft: 60.0,
        marginTop: 0.0,
        marginBottom: 35.0,
        marginRight: 0.0,
        isMetricUnits: true,
      ));
      await mapboxMap!.compass.updateSettings(mapbox.CompassSettings(
        position: mapbox.OrnamentPosition.TOP_RIGHT,
        marginTop: 10.0,
        marginRight: 20.0,
        marginBottom: 0.0,
        marginLeft: 0.0,
      ));
      await mapboxMap!.logo.updateSettings(mapbox.LogoSettings(
        position: mapbox.OrnamentPosition.BOTTOM_LEFT,
        marginLeft: 4.0,
        marginTop: 0.0,
        marginBottom: 4.0,
        marginRight: 0.0,
      ));
      await mapboxMap!.attribution.updateSettings(mapbox.AttributionSettings(
        position: mapbox.OrnamentPosition.BOTTOM_LEFT,
        marginLeft: 92.0,
        marginTop: 0.0,
        marginBottom: 2.0,
        marginRight: 0.0,
      ));
      appLogger.fine("Ornament configuration attempt finished.");

      await mapboxMap!.style
          .setStyleImportConfigProperty("basemap", "show3dObjects", true);
      appLogger.fine("Set show3dObjects config property to true.");
    } catch (e, s) {
      if (mounted && !_isDisposed) {
        appLogger.severe("ERROR configuring ornaments via controller", e, s);
      }
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_isDisposed) {
        _fetchComplaintCoordinates();
      }
    });
  }

  Future<void> _fetchComplaintCoordinates() async {
    if (!mounted || _isDisposed) return;

    appLogger.info("Fetching complaint coordinates...");
    setState(() {
      _isLoadingComplaints = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('complaints')
          .select('id, latitude, longitude, "issueType", status, "imageUrls"')
          .not('latitude', 'is', null)
          .not('longitude', 'is', null);

      if (!mounted || _isDisposed) return;

      _complaintsData = List<Map<String, dynamic>>.from(response);

      if (mounted && !_isDisposed) {
        setState(() {
          _isLoadingComplaints = false;
        });
      }
      appLogger.info(
          "Successfully fetched ${_complaintsData.length} complaint coordinates.");

      _addMarkers();
    } catch (e, s) {
      if (mounted && !_isDisposed) {
        appLogger.severe("Error fetching complaint coordinates", e, s);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching map data: ${e.toString()}')),
        );
        appLogger.warning("Falling back to default initial camera view due to fetch error.");
        if (mapboxMap != null) {
          mapboxMap!.flyTo(_initialCameraOptions,
              mapbox.MapAnimationOptions(duration: 1500));
        }
      }
    } finally {
      if (mounted && !_isDisposed && _isLoadingComplaints) {
        setState(() {
          _isLoadingComplaints = false;
        });
      }
      if (mounted &&
          !_isDisposed &&
          _complaintCoordinates.isEmpty &&
          !_isLoadingComplaints) {
        appLogger.info("Falling back to default initial camera view (no complaints found).");
        if (mapboxMap != null) {
          mapboxMap!.flyTo(_initialCameraOptions,
              mapbox.MapAnimationOptions(duration: 1500));
        }
      }
    }
  }

  Future<void> _addMarkers() async {
    if (_isDisposed ||
        !mounted ||
        _isLoadingComplaints ||
        _complaintsData.isEmpty) {
      appLogger.fine("Add markers skipped: Disposed, not mounted, loading, or no data.");
      return;
    }
    final mapController = mapboxMap;
    if (mapController == null) {
      appLogger.warning("Add markers skipped: Map controller null.");
      return;
    }
    appLogger.info("Adding markers from fetched data...");

    try {
      appLogger.fine("Loading marker image asset...");
      final ByteData bytes = await rootBundle.load('assets/map-point.png');
      final Uint8List imageData = bytes.buffer.asUint8List();
      appLogger.fine("Marker image loaded successfully.");

      if (_isDisposed || !mounted) return;
      _pointAnnotationManager ??=
          await mapController.annotations.createPointAnnotationManager();
      _pointAnnotationManager?.addOnPointAnnotationClickListener(
          _AnnotationClickListener(onTap: _onMarkerTapped));

      if (_pointAnnotationManager == null) {
        appLogger.severe("ERROR: _pointAnnotationManager is null after creation attempt.");
        if (mapboxMap != null) {
          mapboxMap!.flyTo(_initialCameraOptions,
              mapbox.MapAnimationOptions(duration: 1500));
        }
        return;
      }

      await _pointAnnotationManager!.deleteAll();
      setState(() {
        _complaintCoordinates.clear();
        _currentAnnotations.clear();
        _currentMarkerIndex = -1;
        _annotationIdToComplaintId.clear();
        _complaintIdToDataIndex.clear();
      });
      appLogger.fine("Existing markers and coordinates cleared.");

      appLogger.fine("Preparing marker data in background isolate...");
      final preparedData =
          await compute<Map<String, dynamic>, _PreparedAnnotationData>(
        _prepareAnnotationOptions,
        {
          'complaints': _complaintsData,
          'imageData': imageData,
          'initialIconSize': _initialIconSize,
        },
      );
      appLogger.fine("Marker data preparation complete.");

      if (!mounted || _isDisposed) return;

      final allOptions = preparedData.options;
      final allCoordinates = preparedData.coordinates;
      final optionIndexToComplaintId = preparedData.optionIndexToComplaintId;

      if (allOptions.isEmpty) {
        appLogger.warning("No valid marker options generated from fetched data.");
        if (mounted && !_isDisposed) {
          appLogger.info("Falling back to default initial camera view (no valid markers).");
          if (mapboxMap != null) {
            mapboxMap!.flyTo(_initialCameraOptions,
                mapbox.MapAnimationOptions(duration: 1500));
          }
        }
        return;
      }
      
      // --- BATCHING LOGIC START ---
      const batchSize = 500;
      final totalAnnotations = allOptions.length;
      final newAnnotationIdMap = <String, String>{};
      final newCurrentAnnotations = <mapbox.PointAnnotation>[];

      for (int i = 0; i < totalAnnotations; i += batchSize) {
        if (!mounted || _isDisposed) return; 

        final end = (i + batchSize > totalAnnotations) ? totalAnnotations : i + batchSize;
        final batchOptions = allOptions.sublist(i, end);
        
        appLogger.fine("Creating annotation batch ${i ~/ batchSize + 1} with ${batchOptions.length} markers...");

        final List<mapbox.PointAnnotation?> createdBatch =
            await _pointAnnotationManager!.createMulti(batchOptions);

        for (int j = 0; j < createdBatch.length; j++) {
            final annotation = createdBatch[j];
            if (annotation == null) continue;

            final originalIndex = i + j;
            newCurrentAnnotations.add(annotation);

            if (optionIndexToComplaintId.containsKey(originalIndex)) {
                final complaintId = optionIndexToComplaintId[originalIndex]!;
                newAnnotationIdMap[annotation.id] = complaintId;
            } else {
                appLogger.warning("Warning: Could not find original option index or complaint ID for annotation ${annotation.id}");
            }
        }
        
        // Give the UI thread a moment to breathe between batches
        await Future.delayed(const Duration(milliseconds: 50));
      }
      // --- BATCHING LOGIC END ---

      if (mounted && !_isDisposed) {
        setState(() {
          _complaintCoordinates = allCoordinates;
          _currentAnnotations = newCurrentAnnotations;
          _annotationIdToComplaintId = newAnnotationIdMap;
          _complaintIdToDataIndex = preparedData.complaintIdToDataIndex;
        });

        _updateAnnotationSize(_currentZoom, forceUpdate: true);

        if (_complaintCoordinates.isNotEmpty) {
          appLogger.fine("Markers added, setting initial view to fit bounds...");
          Future.delayed(const Duration(milliseconds: 100), () {
            if (!_isDisposed && mounted) {
              _resetCameraView();
            }
          });
        }
      }

      if (!mounted || _isDisposed) {
        appLogger.info("Widget disposed after adding markers.");
        return;
      }
      appLogger.info(
          "SUCCESS: ${newCurrentAnnotations.length} markers added from Supabase data.");
    } catch (e, s) {
      if (mounted && !_isDisposed) {
        appLogger.severe("ERROR adding markers", e, s);
      } else {
        appLogger.warning("Error adding markers occurred, but widget was disposed", e, s);
      }
    }
  }

  Future<void> _zoomIn() async {
    if (_isDisposed || !mounted || mapboxMap == null) {
      return;
    }
    try {
      final currentCamera = await mapboxMap!.getCameraState();
      await mapboxMap!.flyTo(
        mapbox.CameraOptions(
          zoom: currentCamera.zoom + _zoomIncrement,
          center: currentCamera.center,
          bearing: currentCamera.bearing,
          pitch: min(_maxPitch, currentCamera.pitch + _pitchIncrement),
        ),
        mapbox.MapAnimationOptions(duration: 800),
      );
    } catch (e, s) {
      if (mounted && !_isDisposed) appLogger.warning("Error zooming in", e, s);
    }
  }

  Future<void> _zoomOut() async {
    if (_isDisposed || !mounted || mapboxMap == null) return;
    try {
      final currentCamera = await mapboxMap!.getCameraState();
      await mapboxMap!.flyTo(
        mapbox.CameraOptions(
          zoom: max(0, currentCamera.zoom - _zoomIncrement),
          center: currentCamera.center,
          bearing: currentCamera.bearing,
          pitch: max(0.0, currentCamera.pitch - _pitchIncrement),
        ),
        mapbox.MapAnimationOptions(duration: 800),
      );
    } catch (e, s) {
      if (mounted && !_isDisposed) appLogger.warning("Error zooming out", e, s);
    }
  }

  Future<void> _rotateLeft() async {
    if (_isDisposed || !mounted || mapboxMap == null) return;
    try {
      final currentCamera = await mapboxMap!.getCameraState();
      await mapboxMap!.flyTo(
        mapbox.CameraOptions(
          bearing: currentCamera.bearing - _bearingIncrement,
          center: currentCamera.center,
          zoom: currentCamera.zoom,
          pitch: currentCamera.pitch,
        ),
        mapbox.MapAnimationOptions(duration: 1000),
      );
    } catch (e, s) {
      if (mounted && !_isDisposed) appLogger.warning("Error rotating left", e, s);
    }
  }

  Future<void> _rotateRight() async {
    if (_isDisposed || !mounted || mapboxMap == null) return;
    try {
      final currentCamera = await mapboxMap!.getCameraState();
      await mapboxMap!.flyTo(
        mapbox.CameraOptions(
          bearing: currentCamera.bearing + _bearingIncrement,
          center: currentCamera.center,
          zoom: currentCamera.zoom,
          pitch: currentCamera.pitch,
        ),
        mapbox.MapAnimationOptions(duration: 1000),
      );
    } catch (e, s) {
      if (mounted && !_isDisposed) appLogger.warning("Error rotating right", e, s);
    }
  }

  Future<void> _increasePitch() async {
    if (_isDisposed || !mounted || mapboxMap == null) return;
    try {
      final currentCamera = await mapboxMap!.getCameraState();
      final currentPitch = currentCamera.pitch;
      const midPitch = 35.0;

      final targetPitch =
          (currentPitch < midPitch - 1.0) ? midPitch : _maxPitch;
      if ((targetPitch - currentPitch).abs() < 0.1) return;

      await mapboxMap!.flyTo(
        mapbox.CameraOptions(
          pitch: targetPitch,
          center: currentCamera.center,
          zoom: currentCamera.zoom,
          bearing: currentCamera.bearing,
        ),
        mapbox.MapAnimationOptions(duration: 1000),
      );
    } catch (e, s) {
      if (mounted && !_isDisposed) appLogger.warning("Error increasing pitch", e, s);
    }
  }

  Future<void> _decreasePitch() async {
    if (_isDisposed || !mounted || mapboxMap == null) return;
    try {
      final currentCamera = await mapboxMap!.getCameraState();
      final currentPitch = currentCamera.pitch;
      const midPitch = 35.0;
      const minPitch = 0.0;

      final targetPitch =
          (currentPitch > midPitch + 1.0) ? midPitch : minPitch;
      if ((targetPitch - currentPitch).abs() < 0.1) return;

      await mapboxMap!.flyTo(
        mapbox.CameraOptions(
          pitch: targetPitch,
          center: currentCamera.center,
          zoom: currentCamera.zoom,
          bearing: currentCamera.bearing,
        ),
        mapbox.MapAnimationOptions(duration: 1000),
      );
    } catch (e, s) {
      if (mounted && !_isDisposed) appLogger.warning("Error decreasing pitch", e, s);
    }
  }

  Future<void> _flyToCoordinate(int index,
      {bool isCarouselScroll = false}) async {
    if (_isDisposed ||
        !mounted ||
        mapboxMap == null ||
        _complaintCoordinates.isEmpty) return;

    if (index < 0 || index >= _complaintCoordinates.length) {
      appLogger.warning("Fly to coordinate skipped: Invalid index $index");
      return;
    }

    final targetCoordinate = _complaintCoordinates[index];
    appLogger.fine(
        "Flying to marker index $index: ${targetCoordinate.lat}, ${targetCoordinate.lng}");

    mapbox.PointAnnotation? targetAnnotation;
    if (index >= 0 && index < _currentAnnotations.length) {
      // Find annotation by geometry as IDs can be unstable across creations
      final targetGeometry = mapbox.Point(coordinates: targetCoordinate);
      targetAnnotation = _currentAnnotations.firstWhere(
        (a) =>
            a.geometry.toString() == targetGeometry.toJson().toString(),
        orElse: () => _currentAnnotations[index], // Fallback
      );
    }

    try {
      if (isCarouselScroll) {
        await mapboxMap!.flyTo(
          mapbox.CameraOptions(
              center: mapbox.Point(coordinates: targetCoordinate).toJson(),
              zoom: 16.5,
              pitch: 50.0,
              bearing: -15.0),
          mapbox.MapAnimationOptions(duration: 800),
        );
      } else {
        final currentCamera = await mapboxMap!.getCameraState();

        const double intermediateZoom = 10.0;
        const double intermediatePitch = 25.0;
        const double targetZoomLevel = 16.5;
        const double targetPitch = 50.0;
        const double rotationAmount = 25.0;

        await mapboxMap!.flyTo(
          mapbox.CameraOptions(
            center: currentCamera.center,
            zoom: intermediateZoom,
            bearing: currentCamera.bearing,
            pitch: intermediatePitch,
          ),
          mapbox.MapAnimationOptions(duration: 900),
        );

        if (_isDisposed || !mounted) return;
        await Future.delayed(const Duration(milliseconds: 100));
        if (_isDisposed || !mounted) return;

        final Future flyToFuture = mapboxMap!.flyTo(
          mapbox.CameraOptions(
            center: mapbox.Point(coordinates: targetCoordinate).toJson(),
            zoom: targetZoomLevel,
            bearing: currentCamera.bearing + rotationAmount,
            pitch: targetPitch,
          ),
          mapbox.MapAnimationOptions(duration: 2200),
        );

        if (targetAnnotation != null) {
          final nonNullAnnotation = targetAnnotation;
          Future.delayed(const Duration(milliseconds: 1800), () {
            if (mounted && !_isDisposed) {
              _animateMarkerBounce(nonNullAnnotation);
            }
          });
        }

        await flyToFuture;
      }

      if (mounted && !_isDisposed) {
        setState(() {
          _currentMarkerIndex = index;
        });
      }
    } catch (e, s) {
      if (mounted && !_isDisposed) {
        appLogger.warning("Error flying to coordinate", e, s);
      }
    }
  }

  void _goToNextMarker() {
    if (_complaintCoordinates.isEmpty) return;
    int nextIndex = (_currentMarkerIndex + 1) % _complaintCoordinates.length;
    _flyToCoordinate(nextIndex);
  }

  void _goToPreviousMarker() {
    if (_complaintCoordinates.isEmpty) return;
    int prevIndex = (_currentMarkerIndex - 1 + _complaintCoordinates.length) %
        _complaintCoordinates.length;
    _flyToCoordinate(prevIndex);
  }

  void _onMarkerTapped(mapbox.PointAnnotation annotation) {
    if (_isDisposed || !mounted) return;

    _animateMarkerBounce(annotation);

    final complaintId = _annotationIdToComplaintId[annotation.id];
    if (complaintId == null) {
      appLogger.severe("Error: Tapped marker has no corresponding complaint ID. Annotation ID: ${annotation.id}");
      return;
    }

    final index = _complaintIdToDataIndex[complaintId];

    if (index != null) {
      appLogger.fine("Marker tapped, complaint index is $index");
      setState(() {
        _selectedComplaintIndex = index;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController != null && _pageController!.hasClients) {
            _pageController!.animateToPage(
              index,
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeInOut,
            );
          }
        });
      });
    }
  }

  Future<void> _animateMarkerBounce(mapbox.PointAnnotation annotation) async {
    if (_isDisposed || !mounted || _pointAnnotationManager == null) return;

    if (_bouncingAnnotationIds.contains(annotation.id)) {
      appLogger.finer("Skipping bounce for ${annotation.id}: already bouncing.");
      return;
    }

    final double originalSize = _calculateIconSize(_currentZoom);
    final double bounceSize = originalSize * 1.8;
    const bounceDuration = Duration(milliseconds: 250);
    const settleDuration = Duration(milliseconds: 300);

    try {
      _bouncingAnnotationIds.add(annotation.id);

      var bounceAnnotation = annotation;
      bounceAnnotation.iconSize = bounceSize;
      await _pointAnnotationManager?.update(bounceAnnotation);

      if (_isDisposed || !mounted) return;
      await Future.delayed(bounceDuration);

      var originalAnnotation = annotation;
      originalAnnotation.iconSize = originalSize;
      await _pointAnnotationManager?.update(originalAnnotation);

      if (_isDisposed || !mounted) return;
      await Future.delayed(settleDuration);

      final annotationIndex =
          _currentAnnotations.indexWhere((a) => a.id == annotation.id);
      if (annotationIndex != -1 && mounted && !_isDisposed) {
        setState(() {
          _currentAnnotations[annotationIndex] = originalAnnotation;
        });
      }
    } catch (e, s) {
      if (mounted && !_isDisposed) {
        appLogger.warning("Error during marker bounce animation", e, s);
      }
    } finally {
      _bouncingAnnotationIds.remove(annotation.id);
    }
  }

  void _onCarouselPageChanged(int index) {
    if (_isDisposed || !mounted) return;
    setState(() {
      _selectedComplaintIndex = index;
    });
    _flyToCoordinate(index, isCarouselScroll: true);
  }

  void _showComplaintDetailsBottomSheet(String complaintId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (BuildContext context) {
        return ComplaintDetailsSheet(complaintId: complaintId);
      },
    );
  }

  void _onCameraChanged(mapbox.CameraChangedEventData event) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 100), () async {
      if (_isDisposed ||
          !mounted ||
          _pointAnnotationManager == null ||
          _currentAnnotations.isEmpty) {
        return;
      }

      try {
        final cameraState = await mapboxMap?.getCameraState();
        if (cameraState == null || _isDisposed || !mounted) {
          return;
        }
        final newZoom = cameraState.zoom;

        if ((newZoom - _currentZoom).abs() < 0.1 &&
            _currentAnnotations.first.iconSize != null) {
          return;
        }

        _updateAnnotationSize(newZoom);
      } catch (e, s) {
        if (mounted && !_isDisposed) {
          appLogger.warning("Error in _onCameraChanged during size update", e, s);
        }
      }
    });
  }

  Future<void> _updateAnnotationSize(double newZoom,
      {bool forceUpdate = false}) async {
    if (_isDisposed ||
        !mounted ||
        _pointAnnotationManager == null ||
        _currentAnnotations.isEmpty) {
      return;
    }

    final newSize = _calculateIconSize(newZoom);

    final currentSize = _currentAnnotations.first.iconSize ?? _initialIconSize;
    if (!forceUpdate && (newSize - currentSize).abs() < 0.05) {
      return;
    }

    appLogger.finer("Updating annotation size for zoom $newZoom to $newSize");
    _currentZoom = newZoom;

    List<mapbox.PointAnnotation> updatedAnnotations = [];

    for (var annotation in _currentAnnotations) {
      if (_bouncingAnnotationIds.contains(annotation.id)) {
        updatedAnnotations.add(annotation);
        continue;
      }
      var updated = annotation;
      updated.iconSize = newSize;
      updatedAnnotations.add(updated);
    }

    try {
      if (_pointAnnotationManager != null) {
        final futures = <Future>[];
        for (var annotation in updatedAnnotations) {
          futures.add(_pointAnnotationManager!.update(annotation));
        }
        await Future.wait(futures);
      }

      if (mounted && !_isDisposed) {
        setState(() {
          _currentAnnotations = updatedAnnotations;
        });
      }
    } catch (e, s) {
      if (mounted && !_isDisposed) {
        appLogger.warning("Error updating annotation sizes", e, s);
      }
    }
  }

  double _calculateIconSize(double zoom) {
    const minZoom = 10.0;
    const maxZoom = 18.0;
    const minSize = 0.3;
    const maxSize = 1.0;

    if (zoom <= minZoom) return minSize;
    if (zoom >= maxZoom) return maxSize;

    final double t = (zoom - minZoom) / (maxZoom - minZoom);
    final double curvedT = Curves.easeInOut.transform(t);
    return minSize + (maxSize - minSize) * curvedT;
  }

  Future<void> _resetCameraView() async {
    if (_isDisposed || !mounted || mapboxMap == null) {
      return;
    }

    if (_selectedComplaintIndex != null) {
      setState(() {
        _selectedComplaintIndex = null;
      });
    }

    if (_complaintCoordinates.isEmpty) {
      appLogger.info("Resetting camera view to default (no coordinates)...");
      try {
        await mapboxMap!.flyTo(
          _initialCameraOptions,
          mapbox.MapAnimationOptions(duration: 1500),
        );
      } catch (e, s) {
        if (mounted && !_isDisposed) {
          appLogger.warning("Error resetting camera view", e, s);
        }
      }
      return;
    }

    appLogger.fine("Calculating bounds to fit all markers...");
    try {
      List<Map<String?, Object?>> points = _complaintCoordinates
          .map((pos) => mapbox.Point(coordinates: pos).toJson())
          .toList();

      mapbox.CameraOptions cameraOptions =
          await mapboxMap!.cameraForCoordinates(
        points,
        mapbox.MbxEdgeInsets(
            top: 100.0, left: 50.0, bottom: 150.0, right: 50.0),
        null, // bearing
        null, // pitch
      );

      appLogger.fine("Resetting camera view to fit all markers...");
      await mapboxMap!.flyTo(
        cameraOptions,
        mapbox.MapAnimationOptions(duration: 1500),
      );
    } catch (e, s) {
      if (mounted && !_isDisposed) {
        appLogger.warning("Error calculating or flying to bounds", e, s);
      }
    }
  }

  @override
  void dispose() {
    appLogger.info("Disposing MapScreen");
    _debounceTimer?.cancel();
    _pageController?.dispose();
    _isDisposed = true;

    final manager = _pointAnnotationManager;
    if (manager != null) {
      try {
        mapboxMap?.annotations.removeAnnotationManager(manager);
        appLogger.fine("PointAnnotationManager cleaned up.");
      } catch (e, s) {
        appLogger.warning("Error cleaning up PointAnnotationManager", e, s);
      }
      _pointAnnotationManager = null;
    }

    final map = mapboxMap;
    mapboxMap = null;

    try {
      if (map != null) {
        map.dispose();
        appLogger.fine("MapboxMap successfully disposed");
      } else {
        appLogger.fine("No MapboxMap instance to dispose");
      }
    } catch (e, s) {
      appLogger.warning("Error during MapboxMap disposal", e, s);
    }

    super.dispose();
    appLogger.info("MapScreen fully disposed");
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true, // Or a function like: () => _canPopNow(),
      onPopInvoked: (didPop) async {
        if (didPop) {
          return;
        }
        _prepareForNavigation();
        // If you need to conditionally prevent popping, you'd manage `canPop`
        // and call Navigator.pop(context) yourself when ready.
        // For this case, as onWillPop returned true, we assume it can always pop after preparation.
        if (mounted) {
          Navigator.pop(context);
        }
      },
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    SizeConfig().init(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/NCDC Logo.png',
              height: 30,
            ),
            const SizedBox(width: 8),
            const Text('NCDC CCMS'),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _prepareForNavigation();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Stack(
        children: [
          SafeMapboxWidget(
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: _onStyleLoadedCallback,
            onCameraChangeListener: _onCameraChanged,
            cameraOptions: _initialCameraOptions,
            styleUri: mapbox.MapboxStyles.STANDARD,
            textureView: true,
          ),
          MapControls(
            onResetView: _resetCameraView,
            onZoomIn: _zoomIn,
            onZoomOut: _zoomOut,
            onRotateLeft: _rotateLeft,
            onRotateRight: _rotateRight,
            onIncreasePitch: _increasePitch,
            onDecreasePitch: _decreasePitch,
            onPreviousMarker: _goToPreviousMarker,
            onNextMarker: _goToNextMarker,
            canNavigateMarkers: _complaintCoordinates.isNotEmpty,
          ),
          if (_selectedComplaintIndex != null && _pageController != null)
            ComplaintCarousel(
              pageController: _pageController!,
              complaintsData: _complaintsData,
              onPageChanged: _onCarouselPageChanged,
              onShowDetails: _showComplaintDetailsBottomSheet,
              onClose: () {
                setState(() {
                  _selectedComplaintIndex = null;
                });
              },
            ),
          if (_isLoadingComplaints)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
} 