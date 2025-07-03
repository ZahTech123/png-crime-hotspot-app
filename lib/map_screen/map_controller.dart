import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import '../complaint_service.dart';
import '../utils/logger.dart';
import '../utils/map_debug_helper.dart';
import 'map_state.dart';
import 'mapbox_service.dart';

/// Controller class that coordinates map operations
class MapController {
  final MapNotifier _mapNotifier;
  final MapboxService _mapboxService;
  final ComplaintService _complaintService;
  
  // Add context tracking for proper camera operations
  BuildContext? _currentContext;
  
  // Disposal flag to prevent async operations after cleanup
  bool _isDisposed = false;
  
  // Track ongoing operations for cancellation
  bool _isLoadingData = false;

  MapController({
    required MapNotifier mapNotifier,
    required MapboxService mapboxService,
    required ComplaintService complaintService,
  })  : _mapNotifier = mapNotifier,
        _mapboxService = mapboxService,
        _complaintService = complaintService {
    
    // Enable debug mode for camera operations
    MapDebugHelper.setDebugEnabled(true);
    AppLogger.i('[MapController] Initialized with debug mode enabled');
  }

  // Getters to access services and state
  MapNotifier get mapNotifier => _mapNotifier;
  MapboxService get mapboxService => _mapboxService;
  ComplaintService get complaintService => _complaintService;
  MapState get state => _mapNotifier.state;
  bool get isDisposed => _isDisposed;

  /// Store current context for camera operations
  void updateContext(BuildContext context) {
    _currentContext = context;
  }

  /// Clear context reference when no longer valid
  void clearContext() {
    _currentContext = null;
  }

  /// Initialize the map and set up the services (DEPRECATED - use initializeMapSync + loadComplaintDataAsync)
  Future<void> initializeMap(mapbox.MapboxMap mapboxMap) async {
    // Initialize the Mapbox service
    _mapboxService.initialize(mapboxMap);

    // Configure map settings
    await _mapboxService.configureGestures();
    await _mapboxService.configureOrnaments();
    await _mapboxService.add3DBuildings();

    // Set up marker click listener
    _mapboxService.addMarkerClickListener(_onMarkerTapped);

    // Load initial data
    await loadComplaintData();
  }

  /// Initialize map synchronously (immediate operations only)
  Future<void> initializeMapSync(mapbox.MapboxMap mapboxMap) async {
    if (_isDisposed) return;
    
    // Initialize MapboxService with the map instance
    _mapboxService.initialize(mapboxMap);
    
    // Configure basic map settings immediately
    await _mapboxService.configureGestures();
    await _mapboxService.configureOrnaments();
    await _mapboxService.add3DBuildings();

    // Set up marker click listener
    _mapboxService.addMarkerClickListener(_onMarkerTapped);
  }

  /// Load complaint data asynchronously without blocking the UI
  Future<void> loadComplaintDataAsync() async {
    if (_isDisposed || _isLoadingData) return;
    
    _isLoadingData = true;
    await loadComplaintData();
  }

  /// Load complaint data and create markers
  Future<void> loadComplaintData() async {
    if (_isDisposed) return;
    
    _mapNotifier.setLoadingComplaints(true);

    try {
      // Fetch complaints from service
      final complaints = await _complaintService.getComplaintsForMap();
      if (_isDisposed) return;
      
      _mapNotifier.setComplaints(complaints);

      // Create markers if we have complaints
      if (complaints.isNotEmpty && !_isDisposed) {
        final markerResult = await _mapboxService.createMarkers(complaints);
        if (_isDisposed) return;
        
        if (markerResult.isNotEmpty) {
          _mapNotifier.setComplaintCoordinates(
            coordinates: markerResult.coordinates,
            annotations: markerResult.annotations,
            annotationMapping: markerResult.annotationMapping,
          );

          // Reset camera to show all markers with proper context
          if (!_isDisposed) {
            await _mapboxService.resetCameraView(
              markerResult.coordinates, 
              _currentContext,
              isBottomSheetVisible: state.isBottomSheetVisible
            );
          }
        }
      }
    } catch (e) {
      if (!_isDisposed) {
        _mapNotifier.setError('Error loading map data: $e');
        // Fallback to default view on error with proper context
        await _mapboxService.resetCameraView(
          [], 
          _currentContext,
          isBottomSheetVisible: state.isBottomSheetVisible
        );
      }
    } finally {
      _isLoadingData = false;
      // Ensure loading state is cleared
      if (!_isDisposed) {
        _mapNotifier.setLoadingComplaints(false);
      }
    }
  }

  /// Handle marker tap events
  void _onMarkerTapped(mapbox.PointAnnotation annotation) {
    final complaintId = state.annotationIdToComplaintId[annotation.id];
    if (complaintId == null) return;

    showComplaintDetails(complaintId);
  }

  /// Show complaint details in bottom sheet
  Future<void> showComplaintDetails(String complaintId) async {
    if (_isDisposed) return;
    
    // Show loading state
    _mapNotifier.showBottomSheet(complaintsData: null, selectedIndex: 0);

    try {
      final complaintsData = await _complaintService.getComplaintDetailsAndNearby(complaintId);
      if (_isDisposed) return;
      
      _mapNotifier.showBottomSheet(complaintsData: complaintsData, selectedIndex: 0);
    } catch (e) {
      if (!_isDisposed) {
        // Show error state
        _mapNotifier.showBottomSheet(complaintsData: [], selectedIndex: 0);
      }
    }
  }

  /// Hide complaint details bottom sheet
  void hideComplaintDetails() {
    _mapNotifier.hideBottomSheet();
  }

  /// Handle carousel location change
  void onCarouselLocationChange(double lat, double lng) {
    final position = mapbox.Position(lng, lat);
    _mapboxService.flyToCoordinate(position);
  }

  /// Camera control methods
  Future<void> zoomIn() async {
    if (_isDisposed) return;
    await _mapboxService.zoomIn();
  }
  
  Future<void> zoomOut() async {
    if (_isDisposed) return;
    await _mapboxService.zoomOut();
  }
  
  Future<void> rotateLeft() async {
    if (_isDisposed) return;
    await _mapboxService.rotateLeft();
  }
  
  Future<void> rotateRight() async {
    if (_isDisposed) return;
    await _mapboxService.rotateRight();
  }
  
  Future<void> increasePitch() async {
    if (_isDisposed) return;
    await _mapboxService.increasePitch();
  }
  
  Future<void> decreasePitch() async {
    if (_isDisposed) return;
    await _mapboxService.decreasePitch();
  }

  /// Marker navigation methods
  Future<void> goToNextMarker() async {
    if (_isDisposed) return;
    
    final coordinates = state.complaintCoordinates;
    if (coordinates.isEmpty) {
      AppLogger.w('[MapController] Cannot navigate to next marker - no coordinates available');
      return;
    }

    final nextIndex = (state.currentMarkerIndex + 1) % coordinates.length;
    AppLogger.i('[MapController] Navigating to next marker: ${state.currentMarkerIndex} -> $nextIndex');
    await _flyToMarker(nextIndex);
  }

  Future<void> goToPreviousMarker() async {
    if (_isDisposed) return;
    
    final coordinates = state.complaintCoordinates;
    if (coordinates.isEmpty) {
      AppLogger.w('[MapController] Cannot navigate to previous marker - no coordinates available');
      return;
    }

    final prevIndex = (state.currentMarkerIndex - 1 + coordinates.length) % coordinates.length;
    AppLogger.i('[MapController] Navigating to previous marker: ${state.currentMarkerIndex} -> $prevIndex');
    await _flyToMarker(prevIndex);
  }

  /// Fly to a specific marker by index
  Future<void> _flyToMarker(int index) async {
    if (_isDisposed) return;
    
    final coordinates = state.complaintCoordinates;
    if (index < 0 || index >= coordinates.length) {
      AppLogger.e('[MapController] Invalid marker index $index (available: 0-${coordinates.length - 1})');
      return;
    }

    final targetCoordinate = coordinates[index];
    AppLogger.i('[MapController] Flying to marker $index at ${targetCoordinate.lat}, ${targetCoordinate.lng}');

    try {
      // First zoom out to show overview with proper context
      AppLogger.d('[MapController] Step 1: Zooming out to show overview');
      await _mapboxService.resetCameraView(
        coordinates, 
        _currentContext, 
        isBottomSheetVisible: state.isBottomSheetVisible
      );
      if (_isDisposed) return;
      
      // Wait a bit then zoom in to target
      AppLogger.d('[MapController] Step 2: Waiting 2 seconds before zoom in');
      await Future.delayed(const Duration(milliseconds: 2000));
      if (_isDisposed) return;
      
      AppLogger.d('[MapController] Step 3: Zooming in to target marker');
      await _mapboxService.flyToCoordinate(targetCoordinate);
      if (_isDisposed) return;

      // Update current marker index
      _mapNotifier.setCurrentMarkerIndex(index);
      AppLogger.i('[MapController] Successfully navigated to marker $index');
    } catch (e) {
      AppLogger.e('[MapController] Failed to fly to marker $index: $e');
    }
  }

  /// Reset camera view to show all markers
  Future<void> resetCameraView(BuildContext? context) async {
    if (_isDisposed) return;
    
    AppLogger.i('[MapController] Camera reset initiated by user');
    AppLogger.d('[MapController] Current coordinates count: ${state.complaintCoordinates.length}');
    AppLogger.d('[MapController] Bottom sheet visible: ${state.isBottomSheetVisible}');
    
    // Update stored context if provided
    if (context != null) {
      _currentContext = context;
      AppLogger.d('[MapController] Context updated from method parameter');
    }
    
    // Use stored context or provided context for camera reset
    final contextToUse = context ?? _currentContext;
    AppLogger.d('[MapController] Using context: ${contextToUse != null ? 'available' : 'null'}');
    
    // Show loading state for user feedback
    _mapNotifier.clearError(); // Clear any previous errors
    
    try {
      // Validate coordinates before attempting reset
      if (state.complaintCoordinates.isEmpty) {
        AppLogger.i('[MapController] No coordinates available - resetting to default view');
      } else {
        AppLogger.i('[MapController] Resetting camera to encompass ${state.complaintCoordinates.length} markers');
      }
      
      // Perform the camera reset with validation
      await _mapboxService.resetCameraView(
        state.complaintCoordinates, 
        contextToUse, 
        isBottomSheetVisible: state.isBottomSheetVisible
      );
      
      AppLogger.i('[MapController] Camera reset completed successfully');
      
      // Optional: Show brief success feedback (can be removed if too intrusive)
      if (contextToUse != null && state.complaintCoordinates.isNotEmpty) {
        _showBriefFeedback(contextToUse, 'Map view reset to show all markers', isSuccess: true);
      }
      
    } catch (e) {
      AppLogger.e('[MapController] Camera reset failed: $e');
      _mapNotifier.setError('Failed to reset map view: ${e.toString()}');
      
      // Show error feedback to user
      if (contextToUse != null) {
        _showBriefFeedback(contextToUse, 'Failed to reset map view', isSuccess: false);
      }
    }
  }

  /// Show brief user feedback for camera operations
  void _showBriefFeedback(BuildContext context, String message, {required bool isSuccess}) {
    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.error,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: isSuccess ? Colors.green.shade600 : Colors.red.shade600,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
    );
    
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// Handle camera changes (for dynamic marker sizing)
  void onCameraChanged() {
    if (_isDisposed) return;
    
    _mapboxService.setupCameraChangeListener((zoom) async {
      if (!_isDisposed) {
        _mapNotifier.setCurrentZoom(zoom);
        
        // Use optimized batch update with performance monitoring
        final result = await _mapboxService.updateMarkerSizes(state.currentAnnotations, zoom);
        
        // Log performance if significant updates occurred
        if (result.updatedMarkers > 0) {
          AppLogger.d('[MapController] Marker update performance: ${result.toString()}');
        }
      }
    });
  }

  /// Refresh complaint data
  Future<void> refreshData() async {
    if (_isDisposed) return;
    await loadComplaintData();
  }

  /// Clear all data and reset state
  void clearData() {
    if (_isDisposed) return;
    _mapNotifier.clearMarkers();
  }

  /// Dispose resources and cleanup
  void dispose() {
    if (_isDisposed) return;
    
    // Set disposal flag first to stop all ongoing operations
    _isDisposed = true;
    
    // Cancel any ongoing data loading
    _isLoadingData = false;
    
    // Dispose MapboxService (which handles map cleanup)
    _mapboxService.dispose();
    
    // Clear any remaining data
    try {
      _mapNotifier.reset();
    } catch (e) {
      // Silently ignore if notifier is already disposed
    }
    
    // Note: Don't dispose _mapNotifier here as it might be shared between widgets
    // The MapScreen will handle _mapNotifier disposal
  }

  /// Load complaint data with proper error handling (public method)
  Future<void> loadComplaintDataWithErrorHandling() async {
    if (_isDisposed) return;
    
    _mapNotifier.setLoadingComplaints(true);

    try {
      // Fetch complaints from service
      final complaints = await _complaintService.getComplaintsForMap();
      if (_isDisposed) return;
      
      _mapNotifier.setComplaints(complaints);

      // Create markers if we have complaints
      if (complaints.isNotEmpty && !_isDisposed) {
        final markerResult = await _mapboxService.createMarkers(complaints);
        if (_isDisposed) return;
        
        if (markerResult.isNotEmpty) {
          _mapNotifier.setComplaintCoordinates(
            coordinates: markerResult.coordinates,
            annotations: markerResult.annotations,
            annotationMapping: markerResult.annotationMapping,
          );

          // Reset camera to show all markers with proper context
          if (!_isDisposed) {
                    if (!_isDisposed && _currentContext != null) {
          await _mapboxService.resetCameraView(
            markerResult.coordinates, 
            _currentContext,
            isBottomSheetVisible: state.isBottomSheetVisible
          );
        }
          }
        }
      }
    } catch (e) {
      if (!_isDisposed) {
        _mapNotifier.setError('Error loading map data: $e');
        // Fallback to default view on error with proper context
        if (!_isDisposed && _currentContext != null) {
          await _mapboxService.resetCameraView(
            [], 
            _currentContext,
            isBottomSheetVisible: state.isBottomSheetVisible
          );
        }
      }
    } finally {
      // Ensure loading state is cleared even if there's an error
      if (!_isDisposed) {
        _mapNotifier.setLoadingComplaints(false);
      }
    }
  }
}
