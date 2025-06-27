import 'dart:math'; // Import dart:math for max/min functions
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'dart:convert'; // Import dart:convert for jsonEncode
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import 'package:provider/provider.dart'; // Import Provider
import 'dart:typed_data'; // Import for Uint8List
import 'package:flutter/services.dart'; // Import for rootBundle
import 'dart:async'; // Import for Timer
import 'package:flutter/foundation.dart'; // Required for compute

// Import the extracted widget
import 'package:ncdc_ccms_app/map_screen/widgets/safe_mapbox_widget.dart';
// Import the new bottom sheet widget
import 'package:ncdc_ccms_app/map_screen/widgets/complaint_details_sheet.dart';
// Import the map bottom carousel widget
import 'package:ncdc_ccms_app/map_screen/widgets/persistent_bottom_sheet.dart';
// Import the new controls widget
import 'package:ncdc_ccms_app/map_screen/widgets/map_controls.dart';

// --- Data classes for background processing ---

// Input for the isolate
class MarkerCreationInput {
  final List<Map<String, dynamic>> complaintsData;
  final Uint8List markerImageData;
  final double initialIconSize;

  MarkerCreationInput(this.complaintsData, this.markerImageData, this.initialIconSize);
}

// Output from the isolate
class ProcessedMarkerResult {
  final List<mapbox.PointAnnotationOptions> options;
  final List<mapbox.Position> coordinates;
  // Key: a string representation of the coordinate, e.g., "lng,lat"
  // Value: complaint ID
  final Map<String, String> geometryKeyToComplaintId;

  ProcessedMarkerResult(
      this.options, this.coordinates, this.geometryKeyToComplaintId);
}

// --- Top-level function for background processing ---
// This must be a top-level function or a static method to be used with compute.
ProcessedMarkerResult _prepareMarkerData(MarkerCreationInput input) {
  final List<mapbox.PointAnnotationOptions> options = [];
  final List<mapbox.Position> coordinates = [];
  final Map<String, String> geometryKeyToComplaintId = {};

  for (int i = 0; i < input.complaintsData.length; i++) {
    final complaint = input.complaintsData[i];
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
      final geometryKey = "${position.lng},${position.lat}";

      options.add(mapbox.PointAnnotationOptions(
        geometry: mapbox.Point(coordinates: position),
        image: input.markerImageData,
        iconSize: input.initialIconSize,
      ));
      coordinates.add(position);
      geometryKeyToComplaintId[geometryKey] = complaintId;
    }
  }
  return ProcessedMarkerResult(options, coordinates, geometryKeyToComplaintId);
}
// --- End background processing helpers ---

// ======== SAFE MAPBOX WIDGET WRAPPER ========
// This wrapper ensures proper lifecycle management for MapboxMap
// REMOVED SafeMapboxWidget code

// --- Custom Click Listener Class ---
class PointAnnotationClickListener extends mapbox.OnPointAnnotationClickListener {
  final Function(mapbox.PointAnnotation) onTap;
  
  PointAnnotationClickListener({required this.onTap});
  
  @override
  bool onPointAnnotationClick(mapbox.PointAnnotation annotation) {
    onTap(annotation);
    return true; // Indicate the event was handled
  }
}

// --- Map Screen Widget ---
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  mapbox.MapboxMap? mapboxMap;
  bool _isDisposed = false; // Track disposal state
  mapbox.PointAnnotationManager? _pointAnnotationManager; // Manager for markers
  List<Map<String, dynamic>> _complaintsData = []; // To store fetched complaint coordinates
  bool _isLoadingComplaints = true; // Loading state for complaints

  // --- Add state for marker navigation ---
  List<mapbox.Position> _complaintCoordinates = []; // Store valid marker coordinates
  int _currentMarkerIndex = -1; // Index of the currently focused marker
  // --------------------------------------

  // --- State for dynamic marker sizing ---
  List<mapbox.PointAnnotation> _currentAnnotations = []; // Store created annotations
  double _currentZoom = 12.0; // Store current zoom level
  Timer? _debounceTimer; // Timer for debouncing size updates
  static const double _initialIconSize = 0.5; // Store initial size
  // -------------------------------------

  // --- State for marker click handling ---
  Map<String, String> _annotationIdToComplaintId = {};
  
  // --- State for bottom sheet ---
  bool _isBottomSheetVisible = false;
  List<Map<String, dynamic>>? _selectedComplaintsData;
  int? _selectedComplaintIndex;
  // ------------------------------------

  // --- IMPORTANT: Replace with your actual Mapbox access token ---
  // Consider loading this from configuration/environment variables in a real app
  final String _mapboxAccessToken = 'pk.eyJ1Ijoiam9obnNraXBvbGkiLCJhIjoiY201c3BzcDYxMG9neDJscTZqeXQ4MGk4YSJ9.afrO8Lq1P6mIUbSyQ6VCsQ';

  // --- Constants for Camera Adjustments ---
  static const double _zoomIncrement = 1.0;
  static const double _bearingIncrement = 30.0; // Increased rotation amount
  static const double _pitchIncrement = 15.0; // Further increased pitch amount
  static const double _maxPitch = 70.0;       // Max allowed pitch
  static const int _animationDurationMs = 300; // Animation speed for controls (REMAINS FOR OTHER CONTROLS)

  // --- Default Camera View for Reset ---
  static final mapbox.CameraOptions _initialCameraOptions = mapbox.CameraOptions(
      center: mapbox.Point(coordinates: mapbox.Position(147.1803, -9.4438)), // Port Moresby
      zoom: 12.0,
      pitch: 45.0,
      bearing: 0.0,
    );
  // ------------------------------------

  @override
  void initState() {
    super.initState();
    // Set token globally *before* MapWidget is built
    if (_mapboxAccessToken.isNotEmpty && _mapboxAccessToken.startsWith('pk.')) {
       mapbox.MapboxOptions.setAccessToken(_mapboxAccessToken);
       print("Mapbox Access Token set.");
    } else {
       // Handle invalid token scenario immediately
       print("Error: Mapbox Access Token is invalid or missing in initState!");
       // Optionally show an error message or prevent map loading later
    }
  }

  // Method to safely cancel ongoing map operations
  void _cancelMapOperations() {
    final map = mapboxMap;
    if (map != null && !_isDisposed) {
      try {
        // A lightweight operation that can interrupt ongoing processes
       map.style.getStyleURI();
        print("Map operations interrupted before navigation");
      } catch (e) {
        print("Error interrupting map operations: $e");
      }
    }
  }

  // Method to prepare for navigation
  void _prepareForNavigation() {
    if (_isDisposed) return;
    _cancelMapOperations();
    print("Map prepared for navigation");
  }

  void _onMapCreated(mapbox.MapboxMap mapboxMap) async { // Make async for await
    if (_isDisposed || !mounted) return;
    
    print("Map created callback received.");
    this.mapboxMap = mapboxMap;

    // Set initial camera position with pitch for 3D view - REMOVED (will be set after markers load)
    /* try {
      if (_isDisposed || !mounted) return;
      
      await mapboxMap.flyTo(
        mapbox.CameraOptions(
          center: mapbox.Point(coordinates: mapbox.Position(147.1803, -9.4438)), // Port Moresby coordinates
          zoom: 12.0,
          pitch: 45.0, // Keep pitch for 3D view
          bearing: 0.0, // Reset bearing for a standard view initially
        ),
        mapbox.MapAnimationOptions(duration: 1500, startDelay: 0), // Optional animation for initial load
      );
      
      if (_isDisposed || !mounted) return;
      print("Initial camera position set via flyTo (to Port Moresby).");

      // Configure gesture settings
      mapboxMap.gestures.updateSettings(mapbox.GesturesSettings(
        rotateEnabled: true,
        pitchEnabled: true,
        scrollEnabled: true,
        doubleTapToZoomInEnabled: true,
        doubleTouchToZoomOutEnabled: true,
        quickZoomEnabled: true,
      ));
       print("Gesture settings updated.");
    } catch (e) {
      if (mounted) {
        print("Error during map initialization: $e");
      }
    } */

    // Configure gesture settings (Keep this part)
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
      print("Gesture settings updated.");
    } catch (e) {
      if (mounted) {
        print("Error updating gesture settings: $e");
      }
    }
  }

  // Method to apply ornament settings after map is created
  // REMOVED METHOD _applyOrnamentSettings

  // --- Style Loaded Callback ---
   void _onStyleLoadedCallback(mapbox.StyleLoadedEventData data) async {
    if (_isDisposed || !mounted || mapboxMap == null) return;

    print("Style loaded callback received.");

    // --- Attempt to configure ornaments via controller ---
    try {
      print("Configuring ornaments via map controller...");

      // Scale Bar
      mapboxMap!.scaleBar.updateSettings(mapbox.ScaleBarSettings( // Changed from ScaleBarViewOptions
          position: mapbox.OrnamentPosition.BOTTOM_LEFT,
          marginLeft: 60.0,
          marginTop: 0.0,
          marginBottom: 35.0,
          marginRight: 0.0,
          isMetricUnits: true,
      ));
      print("  - Scale bar configured.");

      // Compass
      mapboxMap!.compass.updateSettings(mapbox.CompassSettings( // Changed from CompassViewOptions
          position: mapbox.OrnamentPosition.TOP_RIGHT,
          marginTop: 10.0,
          marginRight: 20.0, // Increased margin to align with buttons
          marginBottom: 0.0,
          marginLeft: 0.0,
      ));
       print("  - Compass configured.");

      // Logo
      mapboxMap!.logo.updateSettings(mapbox.LogoSettings( // Changed from LogoViewOptions
          position: mapbox.OrnamentPosition.BOTTOM_LEFT,
          marginLeft: 4.0,
          marginTop: 0.0,
          marginBottom: 4.0,
          marginRight: 0.0,
      ));
      print("  - Logo configured.");

      // Attribution Button
       mapboxMap!.attribution.updateSettings(mapbox.AttributionSettings( // Changed from AttributionButtonOptions
          position: mapbox.OrnamentPosition.BOTTOM_LEFT,
          marginLeft: 92.0,
          marginTop: 0.0,
          marginBottom: 2.0,
          marginRight: 0.0,
      ));
      print("  - Attribution configured.");

      print("Ornament configuration attempt finished.");

      // --- Explicitly enable 3D objects for the Standard style ---
      // REMOVED FROM HERE

    } catch (e) {
      if (mounted && !_isDisposed) {
        print("ERROR configuring ornaments via controller: $e");
        // It's possible this approach is also incorrect/outdated.
      }
    }
    // -----------------------------------------------------

    // --- Attempt to add 3D Buildings SEPARATELY ---
    try {
        await _add3DBuildings(); // Attempt to add 3D buildings
    } catch (e) {
        if (mounted && !_isDisposed) {
            print("ERROR during _add3DBuildings call from _onStyleLoadedCallback: $e");
            // Log the error but continue execution
        }
    }
    // ------------------------------------------

    // --- Fetch coordinates AFTER attempting ornament/3D config ---
    // This ensures it runs even if _add3DBuildings fails
    _fetchComplaintCoordinates();
  }

  // --- Fetch Complaint Coordinates from Supabase ---
  Future<void> _fetchComplaintCoordinates() async {
    if (!mounted || _isDisposed) return;

    print("Fetching complaint coordinates...");
    if (mounted && !_isDisposed) {
      setState(() {
        _isLoadingComplaints = true;
      });
    }

    bool markersAdded = false;
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('complaints')
          .select('id, latitude, longitude')
          .not('latitude', 'is', null)
          .not('longitude', 'is', null);

      if (!mounted || _isDisposed) return;

      _complaintsData = List<Map<String, dynamic>>.from(response);

      if (_complaintsData.isNotEmpty) {
        print("Successfully fetched ${_complaintsData.length} complaint coordinates.");
        // Now that data is fetched, attempt to add the markers
        markersAdded = await _addMarkers();
      } else {
        print("No complaint coordinates found in database.");
      }

    } catch (e) {
      if (mounted && !_isDisposed) {
        print("Error fetching complaint coordinates: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching map data: $e')),
        );
      }
    } finally {
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoadingComplaints = false;
        });

        // --- Final Camera Positioning Logic ---
        if (markersAdded) {
          // If markers were added, reset the view to fit them.
          print("Positioning camera to fit markers...");
          _resetCameraView();
        } else {
          // If no markers were added (due to error, no data, or empty results),
          // fall back to the default initial view.
          print("Falling back to default initial camera view.");
          if (mapboxMap != null) {
            mapboxMap!.flyTo(_initialCameraOptions, mapbox.MapAnimationOptions(duration: 1500));
          }
        }
        // ------------------------------------
      }
    }
  }

  // --- Helper to add the 3D building layer ---
  Future<void> _add3DBuildings() async {
    if (_isDisposed || !mounted) return;
    
    // Capture mapboxMap locally to avoid issues if it's nulled out during the async gap
    final mapController = mapboxMap;
    if (mapController == null || !mounted) {
      print("Add layer skipped: Map controller null or widget not mounted.");
      return;
    }

    print("Adding 3D building layer...");

    try {
      // Check again before proceeding with async operation
      if (_isDisposed || !mounted) return;

      // For STANDARD style, we need to enable 3D buildings differently
      // The STANDARD style already has 3D buildings built-in, but we need to ensure they're enabled
      
      // For STANDARD style, try common source names
      // Check if composite source exists (most common for 3D buildings)
      bool compositeExists = false;
      try {
        compositeExists = await mapController.style.styleSourceExists("composite");
        if (!mounted || _isDisposed) return; // Check again after await
      } catch (e) {
        print("Could not check for composite source: $e");
      }
      
      String? buildingSourceId;
      if (compositeExists) {
        buildingSourceId = "composite";
        print("Using 'composite' source for 3D buildings");
      } else {
        // Fallback: The STANDARD style usually has 3D buildings enabled by default
        print("INFO: No 'composite' source found. STANDARD style likely has 3D buildings enabled by default.");
        return;
      }

      // Define the layer with simple, reliable properties
      final fillExtrusionLayer = mapbox.FillExtrusionLayer(
        id: "custom-3d-buildings",
        sourceId: buildingSourceId!, // Use detected source
        sourceLayer: "building", // Specific layer within the source
        minZoom: 14.0, // Show buildings starting from zoom level 14
        filter: ['has', 'height'], // Simple filter for buildings with height data
        fillExtrusionColor: Colors.grey.value, // Simple gray color
        fillExtrusionHeightExpression: ["get", "height"], // Simple height expression
        fillExtrusionBaseExpression: ["get", "min_height"], // Simple base expression
        fillExtrusionOpacity: 0.8, // Good opacity for visibility
      );

      print("Attempting to add 'custom-3d-buildings' layer with source: $buildingSourceId");
      await mapController.style.addLayer(fillExtrusionLayer);
      
      // Check mounted status again after await
      if (!mounted || _isDisposed) {
          print("Widget disposed after adding layer.");
          return;
      }
      print("SUCCESS: 'custom-3d-buildings' layer added.");

    } catch (e) {
      // Check mounted status before printing error
      if (mounted && !_isDisposed) {
        print("INFO: Could not add custom 3D buildings layer: $e");
        print("INFO: STANDARD style likely has 3D buildings enabled by default - this is expected.");
      } else {
         print("Error adding 3D buildings layer occurred, but widget was disposed: $e");
      }
    }
  }

  // --- Helper to add markers from Supabase data ---
  // Returns true if markers were successfully added, false otherwise.
  Future<bool> _addMarkers() async {
    print("DEBUG: _addMarkers ENTERED");
    if (_isDisposed || !mounted || _isLoadingComplaints || _complaintsData.isEmpty) {
      print("Add markers skipped: Disposed=$_isDisposed, Mounted=$mounted, Loading=$_isLoadingComplaints, DataEmpty=${_complaintsData.isEmpty}.");
      return false;
    }

    final mapController = mapboxMap;
    if (mapController == null) {
      print("Add markers skipped: Map controller null.");
      return false;
    }

    print("Adding markers from fetched data...");

    try {
      print("Loading marker image asset...");
      final ByteData bytes = await rootBundle.load('assets/map-point.png');
      final Uint8List imageData = bytes.buffer.asUint8List();
      print("Marker image loaded successfully.");

      if (_isDisposed || !mounted) return false;

      // --- Offload processing to a background isolate ---
      print("Preparing marker data in background...");
      final creationInput = MarkerCreationInput(_complaintsData, imageData, _initialIconSize);
      final processedResult = await compute(_prepareMarkerData, creationInput);
      print("Background processing complete. Received ${processedResult.options.length} marker options.");
      // ------------------------------------------------

      if (_isDisposed || !mounted) return false;

      final options = processedResult.options;
      final coordinates = processedResult.coordinates;
      final geometryKeyToComplaintId = processedResult.geometryKeyToComplaintId;

      if (options.isEmpty) {
        print("No valid marker options generated from fetched data.");
        // We now handle the camera fallback in the calling function.
        return false;
      }

      print("DEBUG: Checking/Creating PointAnnotationManager...");
      _pointAnnotationManager ??= await mapController.annotations.createPointAnnotationManager();

      if (_isDisposed || !mounted || _pointAnnotationManager == null) {
        print("DEBUG: PointAnnotationManager creation failed or widget disposed.");
        return false;
      }
      print("DEBUG: PointAnnotationManager exists. Proceeding to clear markers.");

      await _pointAnnotationManager!.deleteAll();
      if(mounted && !_isDisposed) {
        setState(() {
          _complaintCoordinates.clear();
          _currentAnnotations.clear();
          _currentMarkerIndex = -1;
          _annotationIdToComplaintId.clear();
        });
      }
      print("Existing markers and coordinates cleared.");

      print("DEBUG: About to call createMulti with ${options.length} options");
      final List<mapbox.PointAnnotation?> createdAnnotationsNullable = await _pointAnnotationManager!.createMulti(options);
      final List<mapbox.PointAnnotation> createdAnnotations = createdAnnotationsNullable.whereType<mapbox.PointAnnotation>().toList();
      print("DEBUG: Created ${createdAnnotations.length} annotations from ${createdAnnotationsNullable.length} attempts");

      // --- Populate the annotation ID to complaint ID map ---
      final newAnnotationIdMap = <String, String>{};
      
      for (final annotation in createdAnnotations) {
        final coords = annotation.geometry.coordinates;
        final geometryKey = "${coords.lng},${coords.lat}";
        final complaintId = geometryKeyToComplaintId[geometryKey];

        if (complaintId != null) {
          // To handle potential duplicate coordinates, remove the key after use
          // Note: This means if two complaints share exact coordinates, only the first will be mapped.
          // This is an edge case to be aware of.
          newAnnotationIdMap[annotation.id] = complaintId;
          // geometryKeyToComplaintId.remove(geometryKey); // Optional: for strict 1-to-1 mapping
          print("MARKER_DEBUG: Mapping Annotation ID ${annotation.id} to Complaint ID $complaintId");
        } else {
          print("MARKER_ERROR: Could not find complaint ID for annotation at ${coords.lng},${coords.lat}");
        }
      }
      // ------------------------------------------------------

      if (mounted && !_isDisposed) {
        setState(() {
          _complaintCoordinates = coordinates;
          _currentAnnotations = createdAnnotations;
          _annotationIdToComplaintId = newAnnotationIdMap;
        });

        print("MARKER_DEBUG: Final annotation ID to complaint ID mapping:");
        _annotationIdToComplaintId.forEach((annotationId, complaintId) {
          print("  $annotationId -> $complaintId");
        });

        _updateAnnotationSize(_currentZoom, forceUpdate: true);
        
        // --- CAMERA POSITIONING REMOVED FROM HERE ---
      }

      print("DEBUG: About to add click listener");
      print("DEBUG: Checking _pointAnnotationManager status before adding listener: Is null? ${_pointAnnotationManager == null}");
      try {
        _pointAnnotationManager?.addOnPointAnnotationClickListener(
          PointAnnotationClickListener(
            onTap: (mapbox.PointAnnotation annotation) {
              print("MARKER_DEBUG: Listener callback triggered for annotation ID: ${annotation.id}");
              _onMarkerTapped(annotation);
            }
          )
        );
        print("MARKER_DEBUG: Added click listener (addOnPointAnnotationClickListener) to PointAnnotationManager.");
      } catch (e) {
        print("MARKER_ERROR: Failed to add click listener: $e");
      }
      print("MARKER_DEBUG: PointAnnotationManager is ${_pointAnnotationManager == null ? 'NULL' : 'NOT NULL'} after adding listener.");

      if (!mounted || _isDisposed) {
        print("Widget disposed after adding markers.");
        return false;
      }
      print("SUCCESS: ${createdAnnotations.length} markers added from Supabase data.");
      
      // Return true as markers were successfully processed and added
      return createdAnnotations.isNotEmpty;

    } catch (e) {
      if (mounted && !_isDisposed) {
        print("ERROR adding markers: $e");
        print("DEBUG: Error occurred within _addMarkers: $e");
      } else {
        print("Error adding markers occurred, but widget was disposed: $e");
      }
      return false; // Return false on error
    }
  }

  // --- Camera Control Methods ---
  // All have safety checks for disposal status

  Future<void> _zoomIn() async {
    if (_isDisposed || !mounted) return;
    
    // Capture mapboxMap locally
    final mapController = mapboxMap;
    if (mapController == null) return; // Initial check using local controller

    try {
        // Check before async operation
        if (_isDisposed || !mounted) return;
        
        final currentCamera = await mapController.getCameraState(); // Use local controller
        
        // Check again after await
        if (_isDisposed || !mounted) return;

        await mapController.flyTo( // Use local controller
          mapbox.CameraOptions(
            zoom: currentCamera.zoom + _zoomIncrement,
            center: currentCamera.center, // Keep center
            bearing: currentCamera.bearing, // Keep bearing
            pitch: min(_maxPitch, currentCamera.pitch + _pitchIncrement), // Increase pitch on zoom in
          ),
          mapbox.MapAnimationOptions(duration: _animationDurationMs),
        );
    } catch (e) {
        // Check mounted before printing error
        if (mounted && !_isDisposed) {
            print("Error zooming in: $e");
        }
    }
  }

  Future<void> _zoomOut() async {
    if (_isDisposed || !mounted) return;
    
    // Capture mapboxMap locally
    final mapController = mapboxMap;
    if (mapController == null) return;

     try {
        // Check before async operation
        if (_isDisposed || !mounted) return;
        
        final currentCamera = await mapController.getCameraState();
        
        // Check again after await
        if (_isDisposed || !mounted) return;

        await mapController.flyTo(
          mapbox.CameraOptions(
            zoom: max(0, currentCamera.zoom - _zoomIncrement), // Prevent negative zoom
            center: currentCamera.center,
            bearing: currentCamera.bearing,
            pitch: max(0.0, currentCamera.pitch - _pitchIncrement), // Decrease pitch on zoom out
          ),
          mapbox.MapAnimationOptions(duration: _animationDurationMs),
        );
     } catch (e) {
        if (mounted && !_isDisposed) {
            print("Error zooming out: $e");
        }
     }
  }

  Future<void> _rotateLeft() async {
    if (_isDisposed || !mounted) return;
    
    final mapController = mapboxMap;
    if (mapController == null) return;

     try {
        if (_isDisposed || !mounted) return;
        
        final currentCamera = await mapController.getCameraState();
        
        if (_isDisposed || !mounted) return;

        await mapController.flyTo(
          mapbox.CameraOptions(
            bearing: currentCamera.bearing - _bearingIncrement, // Bearing wraps automatically
            center: currentCamera.center,
            zoom: currentCamera.zoom,
            pitch: currentCamera.pitch,
          ),
          mapbox.MapAnimationOptions(duration: 800), // Increased duration for smoother rotation
        );
     } catch (e) {
        if (mounted && !_isDisposed) {
            print("Error rotating left: $e");
        }
     }
  }

   Future<void> _rotateRight() async {
    if (_isDisposed || !mounted) return;
    
    final mapController = mapboxMap;
    if (mapController == null) return;

     try {
        if (_isDisposed || !mounted) return;
        
        final currentCamera = await mapController.getCameraState();
        
        if (_isDisposed || !mounted) return;

        await mapController.flyTo(
          mapbox.CameraOptions(
            bearing: currentCamera.bearing + _bearingIncrement, // Bearing wraps automatically
            center: currentCamera.center,
            zoom: currentCamera.zoom,
            pitch: currentCamera.pitch,
          ),
          mapbox.MapAnimationOptions(duration: 800), // Increased duration for smoother rotation
        );
      } catch (e) {
        if (mounted && !_isDisposed) {
            print("Error rotating right: $e");
        }
      }
  }

  Future<void> _increasePitch() async {
    if (_isDisposed || !mounted) return;
    
    final mapController = mapboxMap;
    if (mapController == null) return;

     try {
        if (_isDisposed || !mounted) return;
        
        final currentCamera = await mapController.getCameraState();
        final currentPitch = currentCamera.pitch;
        const midPitch = 35.0; // Define the mid-point pitch

        if (_isDisposed || !mounted) return;

        // Determine target pitch: mid-point or max
        final targetPitch = (currentPitch < midPitch - 1.0) // Use a small tolerance
            ? midPitch 
            : _maxPitch;

        // Avoid animating if already at target
        if ((targetPitch - currentPitch).abs() < 0.1) return; 

        await mapController.flyTo(
          mapbox.CameraOptions(
            pitch: targetPitch, // Use calculated target pitch
            center: currentCamera.center,
            zoom: currentCamera.zoom,
            bearing: currentCamera.bearing,
          ),
          mapbox.MapAnimationOptions(duration: 800), // Increased duration for smoother pitch
        );
     } catch (e) {
        if (mounted && !_isDisposed) {
            print("Error increasing pitch: $e");
        }
     }
  }

   Future<void> _decreasePitch() async {
    if (_isDisposed || !mounted) return;
    
    final mapController = mapboxMap;
    if (mapController == null) return;

     try {
        if (_isDisposed || !mounted) return;
        
        final currentCamera = await mapController.getCameraState();
        final currentPitch = currentCamera.pitch;
        const midPitch = 35.0; // Define the mid-point pitch
        const minPitch = 0.0; // Define the minimum pitch

        if (_isDisposed || !mounted) return;

        // Determine target pitch: mid-point or min
        final targetPitch = (currentPitch > midPitch + 1.0) // Use a small tolerance
            ? midPitch 
            : minPitch;

        // Avoid animating if already at target
        if ((targetPitch - currentPitch).abs() < 0.1) return; 

        await mapController.flyTo(
          mapbox.CameraOptions(
            pitch: targetPitch, // Use calculated target pitch
            center: currentCamera.center,
            zoom: currentCamera.zoom,
            bearing: currentCamera.bearing,
          ),
          mapbox.MapAnimationOptions(duration: 800), // Increased duration for smoother pitch
        );
     } catch (e) {
        if (mounted && !_isDisposed) {
            print("Error decreasing pitch: $e");
        }
     }
  }

  // --- Marker Navigation Methods ---

  Future<void> _flyToCoordinate(int index) async {
    if (_isDisposed || !mounted || mapboxMap == null || _complaintCoordinates.isEmpty) return;

    if (index < 0 || index >= _complaintCoordinates.length) {
      print("Fly to coordinate skipped: Invalid index $index");
      return;
    }

    final targetCoordinate = _complaintCoordinates[index];
    print("Flying to marker index $index: ${targetCoordinate.lat}, ${targetCoordinate.lng}");

    try {
      // --- Step 1: Zoom out to fit all markers first ---
      print("  Step 1: Zooming out to fit bounds...");
      
      // Calculate the bounds dynamically like the home button
      List<mapbox.Point> points = _complaintCoordinates
          .map((pos) => mapbox.Point(coordinates: pos))
          .toList();
      mapbox.CameraOptions boundsCameraOptions = await mapboxMap!.cameraForCoordinates(
        points,
        mapbox.MbxEdgeInsets(top: 100.0, left: 50.0, bottom: 150.0, right: 50.0), // Same padding as home
        0.0, // Bearing
        0.0, // Pitch (keep it flat for the overview)
      );

      await mapboxMap!.flyTo(
        // Use the calculated center, but override zoom/pitch for forced zoom-out
        mapbox.CameraOptions(
            center: boundsCameraOptions.center, // Center on the bounds
            zoom: 9.0, // Force low zoom
            pitch: 0.0, // Force flat pitch
            bearing: 0.0, // Remove bearing during zoom out (North-up)
        ),
        // boundsCameraOptions, // Don't use the full bounds options directly
        mapbox.MapAnimationOptions(duration: 2000), // Increased duration for smoother zoom out
      );

      // Check if disposed during the first animation
      if (_isDisposed || !mounted) return;
      // -------------------------------------------

      // --- Add a longer delay before zooming in ---
      await Future.delayed(const Duration(milliseconds: 2000)); // Further increased delay
      if (_isDisposed || !mounted) return; // Check again after delay
      // -----------------------------------------

      // --- Step 2: Zoom in to the target marker ---
      print("  Step 2: Zooming in to target...");
      await mapboxMap!.flyTo(
        mapbox.CameraOptions(
          center: mapbox.Point(coordinates: targetCoordinate),
          zoom: 18.5, // Explicitly set zoom (as previously set)
          pitch: 70.0, // Explicitly set pitch (as previously set)
          bearing: 45.0, // Add bearing during zoom in
        ),
        mapbox.MapAnimationOptions(duration: 3000), // Further increased duration for slower arrival/easing
      );
      // -------------------------------------------

      // Update state only after the final animation completes
      if (mounted && !_isDisposed) {
        setState(() {
          _currentMarkerIndex = index;
        });
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        print("Error flying to coordinate: $e");
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
    int prevIndex = (_currentMarkerIndex - 1 + _complaintCoordinates.length) % _complaintCoordinates.length;
    _flyToCoordinate(prevIndex);
  }

  // --- End Marker Navigation Methods ---



  // --- Marker Tap Handler ---
  void _onMarkerTapped(mapbox.PointAnnotation annotation) {
    print("MARKER_DEBUG: _onMarkerTapped ENTERED for annotation ID: ${annotation.id}");
    final complaintId = _annotationIdToComplaintId[annotation.id];

    if (complaintId == null) {
      print("MARKER_ERROR: Complaint ID not found for annotation ${annotation.id}");
      if (!mounted || _isDisposed) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find details for this location.')),
      );
      return;
    }
    print("MARKER_DEBUG: Found Complaint ID: $complaintId for Annotation ID: ${annotation.id}");

    _showComplaintDetailsSheet(complaintId);
  }

  // --- Show Complaint Details ---
  void _showComplaintDetailsSheet(String complaintId) async {
    print("MARKER_DEBUG: _showComplaintDetailsSheet ENTERED for complaint ID: $complaintId");
    if (!mounted || _isDisposed) {
      print("MARKER_ERROR: Cannot show details sheet, widget is not mounted or is disposed.");
      return;
    }

    // Show loading state in the bottom sheet
    setState(() {
      _isBottomSheetVisible = true;
      _selectedComplaintsData = [{'loading': true}];
      _selectedComplaintIndex = 0;
    });

    try {
      print("MARKER_DEBUG: Fetching details for complaint ID: $complaintId");
      final supabase = Supabase.instance.client;
      
      // First get the clicked complaint
      final mainResponse = await supabase
          .from('complaints')
          .select()
          .eq('id', complaintId)
          .single();

      if (!mounted || _isDisposed) {
        print("MARKER_ERROR: Widget disposed after fetching complaint details.");
        return;
      }
      
      final mainComplaint = Map<String, dynamic>.from(mainResponse);
      print("MARKER_DEBUG: Successfully fetched main complaint for ID: $complaintId");

      // Get nearby complaints in the same suburb/electorate
      final nearbyResponse = await supabase
          .from('complaints')
          .select()
          .eq('suburb', mainComplaint['suburb'] ?? '')
          .neq('id', complaintId) // Exclude the main complaint
          .limit(4); // Limit to 4 additional complaints

      List<Map<String, dynamic>> allComplaints = [mainComplaint];
      
      if (nearbyResponse.isNotEmpty) {
        final nearbyComplaints = nearbyResponse
            .map<Map<String, dynamic>>((item) => Map<String, dynamic>.from(item))
            .toList();
        allComplaints.addAll(nearbyComplaints);
        print("MARKER_DEBUG: Found ${nearbyComplaints.length} nearby complaints");
      }

      // Update the bottom sheet with all complaints data
      setState(() {
        _selectedComplaintsData = allComplaints;
        _selectedComplaintIndex = 0; // Start with the clicked complaint
      });

    } catch (e) {
      if (!mounted || _isDisposed) {
         print("MARKER_ERROR: Error occurred but widget was disposed: $e");
         return;
      }
      print("MARKER_ERROR: Error fetching complaint details for ID $complaintId: $e");
      setState(() {
        _selectedComplaintsData = [{'error': 'Error loading details: $e'}];
        _selectedComplaintIndex = 0;
      });
    }
  }

  // --- Hide Complaint Details ---
  void _hideComplaintDetailsSheet() {
    setState(() {
      _isBottomSheetVisible = false;
      _selectedComplaintsData = null;
      _selectedComplaintIndex = null;
    });
  }

  // --- Handle Carousel Location Change ---
  void _onCarouselLocationChange(double lat, double lng) {
    if (mapboxMap != null && mounted && !_isDisposed) {
      mapboxMap!.flyTo(
        mapbox.CameraOptions(
          center: mapbox.Point(coordinates: mapbox.Position(lng, lat)),
          zoom: 17.0,
          pitch: 45.0,
        ),
        mapbox.MapAnimationOptions(duration: 1000, startDelay: 0),
      );
    }
  }

  // --- Camera Change Listener for Dynamic Sizing ---
  void _onCameraChanged(mapbox.CameraChangedEventData event) {
    // Use longer debounce to reduce update frequency significantly
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (_isDisposed || !mounted || _pointAnnotationManager == null || _currentAnnotations.isEmpty) return;

      try {
        // Get current zoom (might need await if camera state is fetched)
        final cameraState = await mapboxMap?.getCameraState();
        if (cameraState == null || _isDisposed || !mounted) return;
        final newZoom = cameraState.zoom;

        // Only update if zoom changed significantly (using larger threshold)
        if ((newZoom - _currentZoom).abs() < 0.5 && _currentAnnotations[0].iconSize != null) return;

        // Update annotation size
        _updateAnnotationSize(newZoom);

      } catch (e) {
        if (mounted && !_isDisposed) {
          print("Error in _onCameraChanged during size update: $e");
        }
      }
    });
  }

  // Helper function to update annotation sizes based on zoom
  Future<void> _updateAnnotationSize(double newZoom, {bool forceUpdate = false}) async {
    if (_isDisposed || !mounted || _pointAnnotationManager == null || _currentAnnotations.isEmpty) return;

    final newSize = _calculateIconSize(newZoom);

    // Check if update is needed (unless forced) - use larger threshold
    final currentSize = _currentAnnotations.first.iconSize ?? _initialIconSize;
    if (!forceUpdate && (newSize - currentSize).abs() < 0.1) {
       // Skip update if size change is minimal
       return;
    }

    print("Updating annotation size for zoom $newZoom to $newSize");
    _currentZoom = newZoom; // Store the new zoom level

    // More efficient update: Use bulk update if available, otherwise update individually
    try {
      // Try to update all annotations in batch for better performance
      final updatedAnnotations = <mapbox.PointAnnotation>[];
      
      for (var annotation in _currentAnnotations) {
        // Only create new annotation if size actually changed
        if ((annotation.iconSize ?? _initialIconSize - newSize).abs() > 0.05) {
          updatedAnnotations.add(mapbox.PointAnnotation(
            id: annotation.id,
            geometry: annotation.geometry,
            image: annotation.image,
            iconSize: newSize,
            // Only copy essential properties for performance
            iconOffset: annotation.iconOffset,
            iconAnchor: annotation.iconAnchor,
            iconOpacity: annotation.iconOpacity,
            iconColor: annotation.iconColor,
          ));
        }
      }

      // Only update if we have annotations to update
      if (updatedAnnotations.isNotEmpty && mounted && !_isDisposed) {
        // Use more efficient update approach
        for (int i = 0; i < updatedAnnotations.length && mounted && !_isDisposed; i++) {
          await _pointAnnotationManager?.update(updatedAnnotations[i]);
          
          // Add small delay between updates to prevent overwhelming the graphics pipeline
          if (i < updatedAnnotations.length - 1) {
            await Future.delayed(const Duration(milliseconds: 5));
          }
        }

        // Update local state efficiently
        if (mounted && !_isDisposed) {
          setState(() {
            _currentAnnotations = _currentAnnotations.map((annotation) {
              final updated = updatedAnnotations.firstWhere(
                (updated) => updated.id == annotation.id,
                orElse: () => annotation,
              );
              return updated;
            }).toList();
          });
        }
      }

    } catch (e) {
       if (mounted && !_isDisposed) {
         print("Error updating annotation sizes: $e");
       }
    }
  }

  // Helper to calculate icon size based on zoom (adjust values as needed)
  double _calculateIconSize(double zoom) {
    // Example: Linear interpolation between zoom levels
    const minZoom = 10.0;
    const maxZoom = 18.0;
    const minSize = 0.3;
    const maxSize = 1.0; // Max size when fully zoomed in

    if (zoom <= minZoom) return minSize;
    if (zoom >= maxZoom) return maxSize;

    // Linear interpolation
    final double zoomRatio = (zoom - minZoom) / (maxZoom - minZoom);
    return minSize + (maxSize - minSize) * zoomRatio;
  }
  // --- End Camera Change Listener ---

  // --- Reset Camera View ---
  Future<void> _resetCameraView() async {
    if (_isDisposed || !mounted || mapboxMap == null) return;

    // If no complaints loaded, just go to the default initial view
    if (_complaintCoordinates.isEmpty) {
      print("Resetting camera view to default (no coordinates)...");
      try {
        await mapboxMap!.flyTo(
          _initialCameraOptions, // Use the predefined initial options
          mapbox.MapAnimationOptions(duration: 1500),
        );
      } catch (e) {
        if (mounted && !_isDisposed) {
          print("Error resetting camera view: $e");
        }
      }
      return;
    }

    print("Calculating bounds to fit all markers...");
    try {
      // Prepare coordinate list for cameraForCoordinates
      List<mapbox.Point> points = _complaintCoordinates
          .map((pos) => mapbox.Point(coordinates: pos))
          .toList();

      // Calculate the camera options to fit the coordinates
      // Add padding so markers are not right at the edge
      mapbox.CameraOptions cameraOptions = await mapboxMap!.cameraForCoordinates(
        points,
        mapbox.MbxEdgeInsets(top: 100.0, left: 50.0, bottom: 150.0, right: 50.0), // Use mapbox.MbxEdgeInsets
        0.0, // Bearing (provide as double)
        0.0, // Pitch (provide as double)
      );

      // Optionally adjust bearing/pitch on the result if desired - REMOVED
      // cameraOptions = cameraOptions.copyWith(bearing: 0, pitch: 0);

      print("Resetting camera view to fit all markers...");
      await mapboxMap!.flyTo(
        cameraOptions,
        mapbox.MapAnimationOptions(duration: 1500),
      );

    } catch (e) {
      if (mounted && !_isDisposed) {
        print("Error calculating or flying to bounds: $e");
        // Fallback to default view on error?
        // await mapboxMap!.flyTo(_initialCameraOptions, mapbox.MapAnimationOptions(duration: 1500));
      }
    }
  }
  // --- End Reset Camera View ---

  // --- Helper method for user-friendly error handling ---
  void _showErrorMessage(String message, {bool isWarning = false}) {
    if (!mounted || _isDisposed) return;
    
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isWarning ? Colors.orange : Colors.red,
          duration: Duration(seconds: isWarning ? 3 : 5),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    } catch (e) {
      print("Error showing error message: $e");
    }
  }

  // --- Enhanced error handling for map operations ---
  void _handleMapError(String operation, dynamic error) {
    print("ERROR in $operation: $error");
    
    // Show user-friendly message based on error type
    String userMessage;
    if (error.toString().contains('network') || error.toString().contains('connection')) {
      userMessage = 'Network error. Please check your internet connection.';
    } else if (error.toString().contains('token') || error.toString().contains('authorization')) {
      userMessage = 'Map authentication error. Please try again.';
    } else if (error.toString().contains('memory') || error.toString().contains('resource')) {
      userMessage = 'Low memory. Please close other apps and try again.';
    } else {
      userMessage = 'Map error occurred. Please try again.';
    }
    
    _showErrorMessage(userMessage);
  }

  @override
  void dispose() {
    print("Disposing MapScreen");
    
    // Cancel timers first to prevent any further execution
    _debounceTimer?.cancel();
    _debounceTimer = null;
    
    // Set disposal flag to prevent further async operations
    _isDisposed = true;
    
    // Clear data structures to free memory
    _complaintCoordinates.clear();
    _currentAnnotations.clear();
    _annotationIdToComplaintId.clear();
    _complaintsData.clear();
    
    // Clear UI state data
    _selectedComplaintsData = null;
    _selectedComplaintIndex = null;
    
    // Clean up annotation manager first if it exists
    final manager = _pointAnnotationManager;
    if (manager != null) {
      try {
        // Clear all annotations before removing manager
        manager.deleteAll().catchError((e) {
          print("Error clearing annotations during disposal: $e");
        });
        
        // Use the map instance to remove the manager
        mapboxMap?.annotations.removeAnnotationManager(manager);
        print("PointAnnotationManager cleaned up.");
      } catch (e) {
         print("Error cleaning up PointAnnotationManager: $e");
      }
      _pointAnnotationManager = null;
    }

    // Safely dispose of the map instance
    final map = mapboxMap; // Capture the reference
    mapboxMap = null; // Nullify the reference immediately
    
    // Safe disposal with try-catch and timeout
    try {
      if (map != null) {
        // Use a timeout to prevent hanging disposal
        Future.delayed(const Duration(seconds: 2), () {
          try {
            map.dispose(); // Call dispose on the captured reference
            print("MapboxMap successfully disposed");
          } catch (e) {
            print("Delayed MapboxMap disposal error: $e");
          }
        });
      } else {
        print("No MapboxMap instance to dispose");
      }
    } catch (e) {
      print("Error during MapboxMap disposal: $e");
      // Don't rethrow - we want to continue with disposal process
    }
    
    super.dispose();
    print("MapScreen fully disposed");
  }

  @override
  Widget build(BuildContext context) {
    // Wrap everything in WillPopScope for navigation safety
    return WillPopScope(
      onWillPop: () async {
        _prepareForNavigation();
        return true; // Allow the navigation to proceed
      },
      child: _buildContent(context),
    );
  }
  
  // Extracted method to build the content - improves readability
  Widget _buildContent(BuildContext context) {
    // Check token validity *before* building the MapWidget
    if (_mapboxAccessToken.isEmpty || !_mapboxAccessToken.startsWith('pk.') || _mapboxAccessToken.contains('YOUR_TOKEN')) {
       print("BUILD ERROR: Mapbox Access Token is invalid or missing!");
       // Return an error placeholder screen
       return Scaffold(
         appBar: AppBar(title: const Text("Map Error")),
         body: const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "Mapbox Access Token is invalid or missing. Please provide a valid token.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red, fontSize: 16),
                ),
            )
          ),
       );
    }

    // If token seems okay, build the map screen
    return Scaffold(
      appBar: AppBar(
        // Use a Row for title to include logo and text
        title: Row(
          mainAxisSize: MainAxisSize.min, // Keep Row width tight
          children: [
            // Add the logo
            Image.asset(
              'assets/NCDC Logo.png',
              height: 30, // Adjust height as needed
              // You might want to add error handling for the image loading
            ),
            const SizedBox(width: 8), // Add spacing between logo and text
            // Add the original title text
            const Text('NCDC CCMS'),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Safety preparation before navigation
            _prepareForNavigation();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Stack( // Use Stack to overlay controls on the map
        children: [
          // Use the SafeMapboxWidget wrapper instead of directly using MapWidget
          SafeMapboxWidget(
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: _onStyleLoadedCallback,
            onCameraChangeListener: _onCameraChanged,
            cameraOptions: mapbox.CameraOptions(
              center: mapbox.Point(coordinates: mapbox.Position(147.1803, -9.4438)), // Port Moresby coordinates
              pitch: 45.0, // Tilt the map to see 3D buildings
              zoom: 16.0,
              bearing: 0.0, // Reset bearing initially
            ),
            styleUri: mapbox.MapboxStyles.STANDARD, // Using Standard style, includes 3D buildings
            textureView: true, // Keep this enabled
          ),

          // --- Use the extracted MapControls widget with bottom padding ---
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
            bottomPadding: _isBottomSheetVisible 
                ? 200.0 // Match carousel container height (180 + padding)
                : 0.0,
          ),
          
          // --- Map Bottom Carousel ---
          MapBottomCarousel(
            complaintsData: _selectedComplaintsData,
            onClose: _hideComplaintDetailsSheet,
            isVisible: _isBottomSheetVisible,
            onLocationChange: _onCarouselLocationChange,
            initialIndex: _selectedComplaintIndex,
          ),
          // ---------------------------------------------
        ],
      ),
    );
  }
}