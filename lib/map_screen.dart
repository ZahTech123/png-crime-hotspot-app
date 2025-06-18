import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:ncdc_ccms_app/map_screen/widgets/complaint_carousel.dart';
import 'package:ncdc_ccms_app/map_screen/widgets/complaint_details_sheet.dart';
import 'package:ncdc_ccms_app/map_screen/widgets/map_controls.dart';
// import 'package:ncdc_ccms_app/map_screen/widgets/safe_mapbox_widget.dart';
import 'package:ncdc_ccms_app/map_screen/widgets/map_widget.dart';
import 'package:ncdc_ccms_app/map_screen/data_providers/complaint_map_data_provider.dart';
import 'package:ncdc_ccms_app/utils/size_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// _AnnotationClickListener moved to map_widget.dart

// _PreparedAnnotationData, _prepareAnnotationOptions (and its renamed version _prepareAnnotationOptionsIsolate),
// and _PrepareAnnotationArgs have been moved to lib/map_screen/data_providers/complaint_map_data_provider.dart

/// Main screen for displaying the map with complaint markers and controls.
///
/// This screen integrates `MapWidget` for the map display and `ComplaintMapDataProvider`
/// for data management. It handles user interactions like marker taps, carousel scrolling,
/// and map controls, delegating map-specific actions to `MapWidget` and data operations
/// to the provider.
class MapScreen extends StatefulWidget {
  final VoidCallback onBack; // Callback invoked when the back button is pressed.
  const MapScreen({super.key, required this.onBack});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late ComplaintMapDataProvider _complaintMapDataProvider;

  // List<Map<String, dynamic>> _complaintsData = []; // Replaced by provider.rawComplaintsData
  // bool _isLoadingComplaints = true; // Replaced by provider.isLoading

  // List<mapbox.Position> _complaintMapCoordinates = []; // This was for camera logic, MapWidget handles its own camera reset based on annotations.

  int? _selectedComplaintIndex; // Index of the currently selected complaint in the carousel.
  PageController? _pageController; // Controller for the complaint details carousel.

  // Data related state variables are now managed by `_complaintMapDataProvider`.

  /// Initial camera position and zoom for the map.
  static final mapbox.CameraOptions _initialCameraOptions = mapbox.CameraOptions(
    center:
        mapbox.Point(coordinates: mapbox.Position(147.1803, -9.4438)).toJson(), // Centered on Port Moresby, PNG
    zoom: 7.0,
    pitch: 0.0,
    bearing: 0.0,
  );

  final GlobalKey<_MapWidgetState> _mapWidgetKey = GlobalKey<_MapWidgetState>();
  mapbox.MapboxMap? _mapboxMapController;


  @override
  void initState() {
    super.initState();
    _complaintMapDataProvider = ComplaintMapDataProvider();
    _complaintMapDataProvider.addListener(_onDataProviderChanged);
    _complaintMapDataProvider.fetchAndPrepareComplaints(); // Initial data fetch

    _pageController = PageController(viewportFraction: 0.85);
  }

  void _onDataProviderChanged() {
    if (mounted) {
      setState(() {
        // Data has changed in the provider, rebuild the widget tree where needed.
      });
    }
  }

  void _cancelMapOperations() {
    // This logic might need to be re-evaluated.
    // If map operations are internal to MapWidget, this might not be needed
    // or MapWidget needs a method that can be called.
    // Attempts to cancel ongoing map operations in the MapWidget.
    // This is typically called before navigating away from the screen.
    _mapWidgetKey.currentState?.cancelMapOperations();
    // debugPrint("MapScreen: _cancelMapOperations called."); // Kept for nav debugging if needed
  }

  /// Prepares for navigation away from the map screen by cancelling map operations.
  void _prepareForNavigation() {
    if (!mounted) return;
    _cancelMapOperations();
    // debugPrint("MapScreen: _prepareForNavigation executed.");
  }

  /// Callback invoked when the `MapWidget` has finished creating the map.
  /// Stores the `MapboxMap` controller and configures map ornaments.
  void _onMapCreatedCallback(mapbox.MapboxMap controller) {
    if (!mounted) return;
    // debugPrint("MapScreen: Map created callback received from MapWidget.");
    _mapboxMapController = controller;
    _configureOrnaments(_mapboxMapController);
  }

  /// Callback invoked when the `MapWidget`'s style is loaded.
  /// Data fetching is primarily handled in `initState`. This can be used for style-specific setup.
  void _onStyleLoadedMapWidgetCallback() {
    if (!mounted) return;
    // debugPrint("MapScreen: Style loaded callback received from MapWidget.");
    // If there's any map configuration that depends on the style being loaded
    // and isn't handled by initial ornament configuration, it can go here.
  }

  /// Callback invoked when the `MapWidget`'s camera becomes idle after movement.
  void _onCameraIdleMapWidgetCallback(mapbox.CameraState cameraState) {
    if (!mounted) return;
    // This can be used for UI updates based on the final camera position/zoom.
    // For example, updating a display of the current zoom level if it were shown in the UI.
    // debugPrint("MapScreen: Camera idle. Zoom: ${cameraState.zoom}");
  }

  /// Callback from `MapWidget` when a marker (annotation) is tapped.
  /// Updates the selected complaint index and animates the carousel to that complaint.
  void _onMarkerTappedMapWidgetCallback(String complaintId) {
    if (!mounted) return;
    // debugPrint("MapScreen: Marker tapped callback for complaint ID: $complaintId");

    final index = _complaintMapDataProvider.complaintIdToDataIndexMap[complaintId];

    if (index != null) {
      // debugPrint("MapScreen: Marker tap corresponds to complaint index: $index");
      setState(() {
        _selectedComplaintIndex = index;
      });
      // Animate the carousel to the page of the tapped marker.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController != null && _pageController!.hasClients && _pageController!.page?.round() != index) {
          _pageController!.animateToPage(
            index,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOut,
          );
        }
      });
    } else {
      if (kDebugMode) print("MapScreen Error: Tapped marker complaint ID $complaintId not found in provider's map.");
    }
  }

  /// Configures map ornaments (scale bar, compass, logo, attribution) using the map controller.
  Future<void> _configureOrnaments(mapbox.MapboxMap? map) async {
    if (map == null || !mounted) return;
    // debugPrint("MapScreen: Configuring ornaments...");
    try {
      await map.scaleBar.updateSettings(mapbox.ScaleBarSettings(
        position: mapbox.OrnamentPosition.BOTTOM_LEFT, marginLeft: 60.0, marginBottom: 35.0, isMetricUnits: true,
      ));
      await map.compass.updateSettings(mapbox.CompassSettings(
        position: mapbox.OrnamentPosition.TOP_RIGHT, marginTop: 10.0, marginRight: 20.0,
      ));
      await map.logo.updateSettings(mapbox.LogoSettings(
        position: mapbox.OrnamentPosition.BOTTOM_LEFT, marginLeft: 4.0, marginBottom: 4.0,
      ));
      await map.attribution.updateSettings(mapbox.AttributionSettings(
        position: mapbox.OrnamentPosition.BOTTOM_LEFT, marginLeft: 92.0, marginBottom: 2.0,
      ));
      // Enable 3D building extrusion if desired.
      await map.style.setStyleImportConfigProperty("basemap", "show3dObjects", true);
      // debugPrint("MapScreen: Ornaments configured and 3D objects enabled.");
    } catch (e) {
      if (mounted && kDebugMode) {
        print("MapScreen: ERROR configuring ornaments: $e");
      }
    }
  }

  // Data fetching and preparation methods (`_fetchComplaintCoordinatesAndPrepareAnnotations`, etc.)
  // have been moved to `ComplaintMapDataProvider`.

  // --- Methods to interact with MapWidget (delegating to _mapWidgetKey.currentState) ---
  // These methods will now call methods on _mapWidgetKey.currentState
  // Or, if MapWidget exposes its own controller, use that.
  // For now, assume _mapWidgetKey.currentState for controls.

  Future<void> _zoomIn() async {
    _mapWidgetKey.currentState?. _zoomIn();
  }

  Future<void> _zoomOut() async {
    _mapWidgetKey.currentState?. _zoomOut();
  }

  Future<void> _rotateLeft() async {
    _mapWidgetKey.currentState?. _rotateLeft();
  }

  Future<void> _rotateRight() async {
    _mapWidgetKey.currentState?. _rotateRight();
  }

  Future<void> _increasePitch() async {
    _mapWidgetKey.currentState?. _increasePitch();
  }

  Future<void> _decreasePitch() async {
    _mapWidgetKey.currentState?. _decreasePitch();
  }

  Future<void> _flyToComplaintByIndex(int index, {bool isCarouselScroll = false}) async {
    if (!mounted || _complaintMapDataProvider.rawComplaintsData.isEmpty || index < 0 || index >= _complaintMapDataProvider.rawComplaintsData.length) {
      debugPrint("Fly to coordinate skipped: Invalid index $index or no data from provider.");
      return;
    }
    final complaint = _complaintMapDataProvider.rawComplaintsData[index];
    final lat = complaint['latitude'];
    final lon = complaint['longitude'];

    if (lat != null && lon != null) {
        final coordinate = {'lat': lat, 'lng': lon};
        _mapWidgetKey.currentState?._flyToCoordinate(coordinate);

        if (mounted && !isCarouselScroll) {
             setState(() { _selectedComplaintIndex = index; });
        }
    } else {
        debugPrint("MapScreen: Cannot fly to complaint index $index: missing coordinates.");
    }
  }


  void _goToNextMarker() {
    if (_complaintMapDataProvider.rawComplaintsData.isEmpty) return;
    int currentIndex = _selectedComplaintIndex ?? -1;
    int nextIndex = (currentIndex + 1) % _complaintMapDataProvider.rawComplaintsData.length;
    _flyToComplaintByIndex(nextIndex);
     if (_pageController != null && _pageController!.hasClients) {
        _pageController!.animateToPage( // TODO: Check if this is still needed, _flyToComplaintByIndex might handle _selectedComplaintIndex
            nextIndex,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOut,
        );
    }
  }

  void _goToPreviousMarker() {
    if (_complaintMapDataProvider.rawComplaintsData.isEmpty) return;
    int currentIndex = _selectedComplaintIndex ?? 0;
    int prevIndex = (currentIndex - 1 + _complaintMapDataProvider.rawComplaintsData.length) % _complaintMapDataProvider.rawComplaintsData.length;
    _flyToComplaintByIndex(prevIndex);
    if (_pageController != null && _pageController!.hasClients) {
        _pageController!.animateToPage( // TODO: Check if this is still needed
            prevIndex,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOut,
        );
    }
  }

  void _onCarouselPageChanged(int index) { // Called by ComplaintCarousel
    if (!mounted) return;
    // _selectedComplaintIndex is already updated by the carousel's onPageChanged
    // We just need to fly to the coordinate.
    _flyToComplaintByIndex(index, isCarouselScroll: true);
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

  // _onCameraChanged is replaced by _onCameraIdleMapWidgetCallback
  // _updateAnnotationSize is now internal to MapWidget
  // _calculateIconSize is now internal to MapWidget

  Future<void> _resetCameraView() async {
    if (!mounted) return;

    if (_selectedComplaintIndex != null) {
      setState(() {
        _selectedComplaintIndex = null;
      });
    }

    // If MapWidget has a method to reset to its initial options or fit bounds, call that.
    if (_mapWidgetKey.currentState != null) {
        _mapWidgetKey.currentState!._resetCameraView();
    } else if (_mapboxMapController != null) {
        // Fallback if direct interaction with MapWidget state is not preferred for this action
        // Check if provider has coordinates, though MapWidget should ideally handle this internally
        if (_complaintMapDataProvider.annotationOptions.isEmpty) {
            debugPrint("MapScreen: Resetting camera view to default (no annotation options from provider)...");
            try {
                await _mapboxMapController!.flyTo(
                    _initialCameraOptions,
                    mapbox.MapAnimationOptions(duration: 1500),
                );
            } catch (e) {
                if (mounted) debugPrint("MapScreen: Error resetting camera view: $e");
            }
        } else {
             // This else block might be redundant if MapWidget's _resetCameraView handles fitting to its annotations
            debugPrint("MapScreen: Asking MapWidget to reset and fit its annotations.");
             _mapWidgetKey.currentState!._resetCameraView(); // Should trigger fit in MapWidget
        }
    }
  }

  @override
  void dispose() {
    debugPrint("Disposing MapScreen");
    _complaintMapDataProvider.removeListener(_onDataProviderChanged);
    // _complaintMapDataProvider.dispose(); // If provider had its own resources to clean up. Not strictly needed for ChangeNotifier itself.
    _pageController?.dispose();
    _mapboxMapController = null;
    super.dispose();
    debugPrint("MapScreen fully disposed");
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _prepareForNavigation();
        widget.onBack(); // Call the passed onBack callback
        return false; // Prevent default pop, navigation handled by onBack
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
            Image.asset('assets/NCDC Logo.png', height: 30),
            const SizedBox(width: 8),
            const Text('NCDC CCMS'),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _prepareForNavigation();
            widget.onBack(); // Call the passed onBack callback
          },
        ),
      ),
      body: Stack(
        children: [
          MapWidget(
            key: _mapWidgetKey,
            initialCameraOptions: _initialCameraOptions,
            styleUri: mapbox.MapboxStyles.STANDARD,
            textureView: true,
            complaintsDataForAnnotations: _complaintMapDataProvider.annotationOptions,
            complaintIdToDataIndexMap: _complaintMapDataProvider.complaintIdToDataIndexMap,
            // annotationToComplaintIdMap is handled internally by MapWidget or not strictly needed if complaintId is in data
            onMapCreatedCallback: _onMapCreatedCallback,
            onStyleLoadedCallback: _onStyleLoadedMapWidgetCallback,
            onCameraIdleCallback: _onCameraIdleMapWidgetCallback,
            onMarkerTappedCallback: _onMarkerTappedMapWidgetCallback,
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
            canNavigateMarkers: _complaintMapDataProvider.rawComplaintsData.isNotEmpty,
          ),
          if (_selectedComplaintIndex != null &&
              _pageController != null &&
              _complaintMapDataProvider.rawComplaintsData.isNotEmpty &&
              _selectedComplaintIndex! < _complaintMapDataProvider.rawComplaintsData.length)
            ComplaintCarousel(
              pageController: _pageController!,
              complaintsData: _complaintMapDataProvider.rawComplaintsData,
              onPageChanged: _onCarouselPageChanged, // This updates _selectedComplaintIndex and calls _flyToComplaintByIndex
              onShowDetails: _showComplaintDetailsBottomSheet,
              onClose: () {
                if (mounted) {
                  setState(() { _selectedComplaintIndex = null; });
                }
              },
            ),
          if (_complaintMapDataProvider.isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}