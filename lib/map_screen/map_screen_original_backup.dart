import 'dart:math'; // Import dart:math for max/min functions
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:ncdc_ccms_app/complaint_provider.dart';
import 'package:ncdc_ccms_app/models.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; // Import for rootBundle
import 'dart:async'; // Import for Timer
import '../utils/logger.dart'; // Import AppLogger

// Import the extracted widget
import 'package:ncdc_ccms_app/map_screen/widgets/safe_mapbox_widget.dart';
// Import the new bottom sheet widget
// Import the map bottom carousel widget
import 'package:ncdc_ccms_app/map_screen/widgets/persistent_bottom_sheet.dart';
// Import the new controls widget
import 'package:ncdc_ccms_app/map_screen/widgets/map_controls.dart';
// Import the optimized icon service
import 'package:ncdc_ccms_app/map_screen/map_icon_service.dart';

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
  List<Complaint> _complaints = []; // To store fetched complaints
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
  List<Complaint>? _selectedComplaintsData;
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
    } else {
       // Handle invalid token scenario immediately
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
      } catch (e) {
        // Silently ignore errors during cancellation.
      }
    }
  }

  // Method to prepare for navigation
  void _prepareForNavigation() {
    if (_isDisposed) return;
    _cancelMapOperations();
  }

  void _onMapCreated(mapbox.MapboxMap mapboxMap) async { // Make async for await
    if (_isDisposed || !mounted) return;
    
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

      // Configure gesture settings
      mapboxMap.gestures.updateSettings(mapbox.GesturesSettings(
        rotateEnabled: true,
        pitchEnabled: true,
        scrollEnabled: true,
        doubleTapToZoomInEnabled: true,
        doubleTouchToZoomOutEnabled: true,
        quickZoomEnabled: true,
      ));
    } catch (e) {
      if (mounted) {
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
    } catch (e) {
      if (mounted) {
        // Silently ignore gesture settings errors.
      }
    }
  }

  // Method to apply ornament settings after map is created
  // REMOVED METHOD _applyOrnamentSettings

  // --- Style Loaded Callback ---
   void _onStyleLoadedCallback(mapbox.StyleLoadedEventData data) async {
    if (_isDisposed || !mounted || mapboxMap == null) return;


    // --- Attempt to configure ornaments via controller ---
    try {

      // Scale Bar
      mapboxMap!.scaleBar.updateSettings(mapbox.ScaleBarSettings( // Changed from ScaleBarViewOptions
          position: mapbox.OrnamentPosition.BOTTOM_LEFT,
          marginLeft: 60.0,
          marginTop: 0.0,
          marginBottom: 35.0,
          marginRight: 0.0,
          isMetricUnits: true,
      ));

      // Compass
      mapboxMap!.compass.updateSettings(mapbox.CompassSettings( // Changed from CompassViewOptions
          position: mapbox.OrnamentPosition.TOP_RIGHT,
          marginTop: 10.0,
          marginRight: 20.0, // Increased margin to align with buttons
          marginBottom: 0.0,
          marginLeft: 0.0,
      ));

      // Logo
      mapboxMap!.logo.updateSettings(mapbox.LogoSettings( // Changed from LogoViewOptions
          position: mapbox.OrnamentPosition.BOTTOM_LEFT,
          marginLeft: 4.0,
          marginTop: 0.0,
          marginBottom: 4.0,
          marginRight: 0.0,
      ));

      // Attribution Button
       mapboxMap!.attribution.updateSettings(mapbox.AttributionSettings( // Changed from AttributionButtonOptions
          position: mapbox.OrnamentPosition.BOTTOM_LEFT,
          marginLeft: 92.0,
          marginTop: 0.0,
          marginBottom: 2.0,
          marginRight: 0.0,
      ));


      // --- Explicitly enable 3D objects for the Standard style ---
      // REMOVED FROM HERE

    } catch (e) {
      if (mounted && !_isDisposed) {
        // It's possible this approach is also incorrect/outdated. Silently ignore.
      }
    }
    // -----------------------------------------------------

    // --- Attempt to add 3D Buildings SEPARATELY ---
    try {
        await _add3DBuildings(); // Attempt to add 3D buildings
    } catch (e) {
        if (mounted && !_isDisposed) {
            // Log the error but continue execution. Silently ignore.
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

    setState(() {
      _isLoadingComplaints = true;
    });

    try {
      // Get ComplaintService via ComplaintProvider (same as other screens)
      final complaintService = Provider.of<ComplaintProvider>(context, listen: false).complaintService;

      final fetchedComplaints = await complaintService.getComplaintsForMap();

      if (!mounted || _isDisposed) return;

      _complaints = fetchedComplaints;

      // --- Set loading state to false BEFORE adding markers ---
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoadingComplaints = false;
        });
      }
      // -------------------------------------------------------


      // Now that data is fetched AND loading state is updated, add the markers
      _addMarkers();

    } catch (e) {
      if (mounted && !_isDisposed) {
        // Optionally show an error message to the user
        if (mounted && !_isDisposed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching map data: $e')),
          );
        }
        // --- Fallback to default view on error ---
        if (mapboxMap != null) { // Ensure map is created
           mapboxMap!.flyTo(_initialCameraOptions, mapbox.MapAnimationOptions(duration: 1500));
        }
        // ------------------------------------------
      }
    } finally {
      // Ensure loading state is false even if there was an error or markers weren't added
      if (mounted && !_isDisposed && _isLoadingComplaints) { // Only set if still true
        setState(() {
          _isLoadingComplaints = false;
        });
      }
      // --- Fallback if fetch succeeded but resulted in no data ---
      if (mounted && !_isDisposed && _complaintCoordinates.isEmpty && !_isLoadingComplaints) {
          if (mapboxMap != null) { // Ensure map is created
             mapboxMap!.flyTo(_initialCameraOptions, mapbox.MapAnimationOptions(duration: 1500));
          }
      }
      // -----------------------------------------------------------
    }
  }

  // --- Helper to add the 3D building layer ---
  Future<void> _add3DBuildings() async {
    if (_isDisposed || !mounted) return;
    
    // Capture mapboxMap locally to avoid issues if it's nulled out during the async gap
    final mapController = mapboxMap;
    if (mapController == null || !mounted) {
      return;
    }


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
        // Silently ignore if source check fails.
      }
      
      String? buildingSourceId;
      if (compositeExists) {
        buildingSourceId = "composite";
      } else {
        // Fallback: The STANDARD style usually has 3D buildings enabled by default
        return;
      }

      // Define the layer with simple, reliable properties
      final fillExtrusionLayer = mapbox.FillExtrusionLayer(
        id: "custom-3d-buildings",
        sourceId: buildingSourceId, // Use detected source
        sourceLayer: "building", // Specific layer within the source
        minZoom: 14.0, // Show buildings starting from zoom level 14
        filter: ['has', 'height'], // Simple filter for buildings with height data
        fillExtrusionColor: 0xFF9E9E9E, // Simple gray color, avoids deprecated .value
        fillExtrusionHeightExpression: ["get", "height"], // Simple height expression
        fillExtrusionBaseExpression: ["get", "min_height"], // Simple base expression
        fillExtrusionOpacity: 0.8, // Good opacity for visibility
      );

      await mapController.style.addLayer(fillExtrusionLayer);
      
      // Check mounted status again after await
      if (!mounted || _isDisposed) {
          return;
      }

    } catch (e) {
      // Check mounted status before printing error
      if (mounted && !_isDisposed) {
        // Silently ignore errors adding 3D buildings.
      } else {
      }
    }
  }

  // --- Helper to add markers from Supabase data ---
  Future<void> _addMarkers() async {
    if (_isDisposed || !mounted || _isLoadingComplaints || _complaints.isEmpty) {
      return;
    }

    // Capture mapboxMap locally
    final mapController = mapboxMap;
    if (mapController == null) {
      return;
    }


    try {
      // --- Get optimized icon data from cache ---
      Uint8List imageData;
      try {
        await MapIconService.instance.initialize();
        imageData = MapIconService.instance.originalIcon;
        AppLogger.d('[MapScreen] Using cached icon data');
      } catch (e) {
        // Fallback to asset loading
        AppLogger.w('[MapScreen] Icon service unavailable, using fallback: $e');
        final ByteData bytes = await rootBundle.load('assets/map-point.png');
        imageData = bytes.buffer.asUint8List();
      }
      // -----------------------------------------

      // Check again before proceeding with async annotation manager creation
      if (_isDisposed || !mounted) return;

      // Create the annotation manager if it doesn't exist
      _pointAnnotationManager ??= await mapController.annotations.createPointAnnotationManager();

      // Check again after potential await
      if (_isDisposed || !mounted || _pointAnnotationManager == null) {
        return;
      }

      // --- Clear existing markers and coordinates before adding new ones ---
      await _pointAnnotationManager!.deleteAll();
      setState(() { // Clear coordinates list and reset index
        _complaintCoordinates.clear();
        _currentAnnotations.clear(); // Clear stored annotations
        _currentMarkerIndex = -1;
        _annotationIdToComplaintId.clear(); // <-- Clear the ID map
      });
      // --------------------------------------------------------------------

      // Define marker options from fetched data
      final List<mapbox.PointAnnotationOptions> options = [];
      final List<mapbox.Position> coordinates = []; // Temporary list for this run
      final Map<int, String> optionIndexToComplaintId = {}; // Temporary map to link option index to complaint ID

      for (int i = 0; i < _complaints.length; i++) {
        final complaint = _complaints[i];
        
        final double latitude = complaint.latitude;
        final double longitude = complaint.longitude;
        final String complaintId = complaint.id;

        // Only create an option if lat, lon, and ID are valid
        if (latitude != null && longitude != null && complaintId.isNotEmpty) {
          final position = mapbox.Position(longitude, latitude);
          // --- Print the coordinates being used ---
          // ----------------------------------------
          options.add(mapbox.PointAnnotationOptions(
            geometry: mapbox.Point(coordinates: position),
            // --- Use the loaded image data directly ---
            image: imageData,
            iconSize: _initialIconSize, // Use initial size
            // -----------------------------------------
            // textField: 'Complaint', // Optionally add text
            // textColor: Colors.black.value,
            // textSize: 12.0,
            // ---------------------------------------------
          ));
          coordinates.add(position); // Add the valid position to our list
          optionIndexToComplaintId[options.length - 1] = complaintId; // Map option index to ID
        } else {
          // No need for null return, just skip adding
        }
      }

      if (options.isEmpty) {
         // --- Fallback if fetch succeeded but resulted in no valid markers ---
         if (mounted && !_isDisposed) {
             if (mapboxMap != null) {
                mapboxMap!.flyTo(_initialCameraOptions, mapbox.MapAnimationOptions(duration: 1500));
             }
         }
         // --------------------------------------------------------------------
        return;
      }

      // Create the markers on the map
      // createMulti can return nulls if some creations fail
      final List<mapbox.PointAnnotation?> createdAnnotationsNullable = await _pointAnnotationManager!.createMulti(options);
      // Filter out nulls before storing
      final List<mapbox.PointAnnotation> createdAnnotations = createdAnnotationsNullable.whereType<mapbox.PointAnnotation>().toList();

      // --- Populate the annotation ID to complaint ID map ---
      final newAnnotationIdMap = <String, String>{};
      for (int i = 0; i < createdAnnotations.length; i++) {
        final annotation = createdAnnotations[i];
        // Find the corresponding complaint ID using the original option index
        // This assumes the order is preserved and nulls are filtered correctly
        // A safer approach might involve matching geometry if order isn't guaranteed.
        // For now, we assume the index corresponds after filtering nulls.
        int originalOptionIndex = -1;
        int currentNonNullIndex = -1;
        for(int j=0; j < createdAnnotationsNullable.length; j++) {
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
           newAnnotationIdMap[annotation.id] = complaintId;
        } else {
        }
      }
      // ------------------------------------------------------

      // Update the state with the coordinates list and annotations
      if (mounted && !_isDisposed) {
          setState(() {
              _complaintCoordinates = coordinates;
              _currentAnnotations = createdAnnotations; // Store the created annotations
              _annotationIdToComplaintId = newAnnotationIdMap; // <-- Update the ID map
          });
          
          _annotationIdToComplaintId.forEach((annotationId, complaintId) {
          });

          // Apply the initial size based on current zoom AFTER annotations are created
          _updateAnnotationSize(_currentZoom, forceUpdate: true);

          // --- Set initial view to fit markers --- (Keep this)
          if (_complaintCoordinates.isNotEmpty) {
            // Use a short delay to ensure map is fully ready after style load/annotation add
            Future.delayed(const Duration(milliseconds: 100), () {
               if (!_isDisposed && mounted) {
                  _resetCameraView();
               }
            });
          }
          // -----------------------------------------
      }

       // --- Add check right before adding listener ---
       // ----------------------------------------------
       // --- Add the click listener using the custom class ---
       try {
         _pointAnnotationManager?.addOnPointAnnotationClickListener(
           PointAnnotationClickListener(
             onTap: (mapbox.PointAnnotation annotation) {
               _onMarkerTapped(annotation);
             }
           )
         );
       } catch (e) {
        // Silently ignore if adding listener fails.
       }
       // ------------------------------------------------------------------------

      // Check mounted status again after await
      if (!mounted || _isDisposed) {
          return;
      }

    } catch (e) {
      // Check mounted status before printing error
      if (mounted && !_isDisposed) {
      } else {
      }
    }
    // --- Add print at the end of the function ---
    // ------------------------------------------
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
          // Silently ignore zoom-out errors.
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
          // Silently ignore rotation errors.
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
          // Silently ignore rotation errors.
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
          // Silently ignore pitch errors.
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
          // Silently ignore pitch errors.
        }
     }
  }

  // --- Marker Navigation Methods ---

  Future<void> _flyToCoordinate(int index) async {
    if (_isDisposed || !mounted || mapboxMap == null || _complaintCoordinates.isEmpty) return;

    if (index < 0 || index >= _complaintCoordinates.length) {
      return;
    }

    final targetCoordinate = _complaintCoordinates[index];

    try {
      // --- Step 1: Zoom out to fit all markers first ---
      
      // Calculate the bounds dynamically like the home button
      List<mapbox.Point> points = _complaintCoordinates
          .map((pos) => mapbox.Point(coordinates: pos))
          .toList();

      // Create a ScreenBox from the context size
      final screenSize = MediaQuery.of(context).size;
      final screenPadding = MediaQuery.of(context).padding;
      final appBarHeight = kToolbarHeight; // Use constant for safety
      final bottomSheetHeight = _isBottomSheetVisible ? 200.0 : 0.0; // Account for bottom sheet

      // Create a ScreenBox that represents the map's visible area, excluding the app bar and bottom sheet
      final screenBox = mapbox.ScreenBox(
          min: mapbox.ScreenCoordinate(x: 0, y: screenPadding.top + appBarHeight),
          max: mapbox.ScreenCoordinate(x: screenSize.width, y: screenSize.height - bottomSheetHeight),
      );

      mapbox.CameraOptions boundsCameraOptions = await mapboxMap!.cameraForCoordinatesCameraOptions(
        points,
        mapbox.CameraOptions(
          padding: mapbox.MbxEdgeInsets(top: 100.0, left: 50.0, bottom: 150.0, right: 50.0), // Same padding as home
          bearing: 0.0, // Bearing
          pitch: 0.0, // Pitch (keep it flat for the overview)
        ),
        screenBox,
      );

      await mapboxMap!.flyTo(
        // Use the calculated center, but override zoom/pitch for forced zoom-out
        mapbox.CameraOptions(
            center: boundsCameraOptions.center, // Center on the bounds
            zoom: 9.0, // Force low zoom
            pitch: 0.0, // Force flat pitch
            bearing: 0.0, // Remove bearing during zoom out (North-up)
        ),
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
        // Silently ignore fly-to errors.
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
    final complaintId = _annotationIdToComplaintId[annotation.id];

    if (complaintId == null) {
      if (!mounted || _isDisposed) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find details for this location.')),
      );
      return;
    }

    _showComplaintDetailsSheet(complaintId);
  }

  // --- Show Complaint Details ---
  void _showComplaintDetailsSheet(String complaintId) async {
    if (!mounted || _isDisposed) {
      return;
    }

    // Show loading state in the bottom sheet
    setState(() {
      _isBottomSheetVisible = true;
      _selectedComplaintsData = null; // Set to null to show loading indicator
      _selectedComplaintIndex = 0;
    });

    try {
      final complaintService = Provider.of<ComplaintProvider>(context, listen: false).complaintService;
      
      final allComplaints = await complaintService.getComplaintDetailsAndNearby(complaintId);

      // Update the bottom sheet with all complaints data
      if (!mounted || _isDisposed) return;
      setState(() {
        _selectedComplaintsData = allComplaints;
        _selectedComplaintIndex = 0; // Start with the clicked complaint
      });

    } catch (e) {
      if (!mounted || _isDisposed) {
         return;
      }
      // In a real app, you might want a more specific error state object
      // For now, we can use an empty list and show an error message in the UI
      setState(() {
         _isBottomSheetVisible = true; // Keep sheet visible to show error
        _selectedComplaintsData = []; 
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
          // Silently ignore camera change errors.
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
        // Silently ignore annotation size update errors.
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
      try {
        await mapboxMap!.flyTo(
          _initialCameraOptions, // Use the predefined initial options
          mapbox.MapAnimationOptions(duration: 1500),
        );
      } catch (e) {
        if (mounted && !_isDisposed) {
          // Silently ignore camera reset errors.
        }
      }
      return;
    }

    try {
      // Prepare coordinate list for cameraForCoordinates
      List<mapbox.Point> points = _complaintCoordinates
          .map((pos) => mapbox.Point(coordinates: pos))
          .toList();

      // Get screen dimensions and app bar height to calculate the correct map view area
      final screenSize = MediaQuery.of(context).size;
      final screenPadding = MediaQuery.of(context).padding;
      final appBarHeight = kToolbarHeight; // Use constant for safety
      final bottomSheetHeight = _isBottomSheetVisible ? 200.0 : 0.0; // Account for bottom sheet

      // Create a ScreenBox that represents the map's visible area, excluding the app bar and bottom sheet
      final screenBox = mapbox.ScreenBox(
          min: mapbox.ScreenCoordinate(x: 0, y: screenPadding.top + appBarHeight),
          max: mapbox.ScreenCoordinate(x: screenSize.width, y: screenSize.height - bottomSheetHeight),
      );

      // Calculate the camera options to fit the coordinates within the corrected view
      mapbox.CameraOptions cameraOptions = await mapboxMap!.cameraForCoordinatesCameraOptions(
        points,
        mapbox.CameraOptions(
          padding: mapbox.MbxEdgeInsets(top: 40.0, left: 40.0, bottom: 40.0, right: 40.0), // Use more balanced padding
          bearing: 0.0, // Reset bearing
          pitch: 0.0,   // Reset pitch
        ),
        screenBox,
      );

      await mapboxMap!.flyTo(
        cameraOptions,
        mapbox.MapAnimationOptions(duration: 1500),
      );

    } catch (e) {
      if (mounted && !_isDisposed) {
        // Fallback to default view on error.
        await mapboxMap!.flyTo(_initialCameraOptions, mapbox.MapAnimationOptions(duration: 1500));
      }
    }
  }
  // --- End Reset Camera View ---

  @override
  void dispose() {
    // Cancel timers first to prevent any further execution
    _debounceTimer?.cancel();
    _debounceTimer = null;
    
    // Set disposal flag to prevent further async operations
    _isDisposed = true;
    
    // Clear data structures to free memory
    _complaintCoordinates.clear();
    _currentAnnotations.clear();
    _annotationIdToComplaintId.clear();
    _complaints.clear();
    
    // Clear UI state data
    _selectedComplaintsData = null;
    _selectedComplaintIndex = null;
    
    // Clean up annotation manager first if it exists
    final manager = _pointAnnotationManager;
    if (manager != null) {
      try {
        // Clear all annotations before removing manager
        manager.deleteAll().catchError((e) {
          // Silently ignore errors on delete.
        });
        
        // Use the map instance to remove the manager
        mapboxMap?.annotations.removeAnnotationManager(manager);
      } catch (e) {
        // Silently ignore errors removing annotation manager.
      }
      _pointAnnotationManager = null;
    }

    // CRITICAL FIX: Dispose the controller to release native resources properly
    final map = mapboxMap;
    mapboxMap = null; // Nullify immediately to prevent further access
    
    if (map != null) {
      try {
        // Dispose immediately without dangerous delays
        map.dispose();
        AppLogger.i("MapScreen: Map successfully disposed");
      } catch (e) {
        AppLogger.e("MapScreen: Error during disposal", e);
        // Don't rethrow - we want to continue with disposal process
      }
    }
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Wrap everything in PopScope for navigation safety
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _prepareForNavigation();
        Navigator.of(context).pop();
      },
      child: _buildContent(context),
    );
  }
  
  // Extracted method to build the content - improves readability
  Widget _buildContent(BuildContext context) {
    // Check token validity *before* building the MapWidget
    if (_mapboxAccessToken.isEmpty || !_mapboxAccessToken.startsWith('pk.') || _mapboxAccessToken.contains('YOUR_TOKEN')) {
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
            // FIX: Provide proper initial camera options to prevent zoom calculation errors
            cameraOptions: mapbox.CameraOptions(
              center: mapbox.Point(coordinates: mapbox.Position(147.1803, -9.4438)), // Port Moresby coordinates
              pitch: 45.0, // Tilt the map to see 3D buildings
              zoom: 12.0, // Use a reasonable default zoom level
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