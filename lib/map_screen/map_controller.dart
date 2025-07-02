import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import '../complaint_service.dart';
import 'map_state.dart';
import 'mapbox_service.dart';

/// Controller class that coordinates map operations
class MapController {
  final MapNotifier _mapNotifier;
  final MapboxService _mapboxService;
  final ComplaintService _complaintService;
  
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
        _complaintService = complaintService;

  // Getters to access services and state
  MapNotifier get mapNotifier => _mapNotifier;
  MapboxService get mapboxService => _mapboxService;
  ComplaintService get complaintService => _complaintService;
  MapState get state => _mapNotifier.state;
  bool get isDisposed => _isDisposed;

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

  /// Initialize map synchronously - only immediate, non-blocking setup
  Future<void> initializeMapSync(mapbox.MapboxMap mapboxMap) async {
    // Initialize the Mapbox service
    _mapboxService.initialize(mapboxMap);

    // Configure map settings (these are fast, non-blocking operations)
    await _mapboxService.configureGestures();
    await _mapboxService.configureOrnaments();
    await _mapboxService.add3DBuildings();

    // Set up marker click listener
    _mapboxService.addMarkerClickListener(_onMarkerTapped);

    // NOTE: Data loading is now handled separately by loadComplaintDataAsync()
  }

  /// Load complaint data asynchronously without blocking the UI
  void loadComplaintDataAsync() {
    if (_isDisposed || _isLoadingData) return;
    
    // Start loading data in the background
    // This doesn't return a Future to avoid blocking the caller
    _loadComplaintDataInBackground();
  }

  /// Internal method to load complaint data in background
  Future<void> _loadComplaintDataInBackground() async {
    if (_isDisposed) return;
    
    _isLoadingData = true;
    
    try {
      // Set loading state
      if (!_isDisposed) {
        _mapNotifier.setLoadingComplaints(true);
      }

      // Small delay to ensure UI has rendered
      await Future.delayed(const Duration(milliseconds: 100));
      if (_isDisposed) return;

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

          // Reset camera to show all markers
          if (!_isDisposed) {
            await _mapboxService.resetCameraView(markerResult.coordinates, null);
          }
        }
      }
    } catch (e) {
      if (!_isDisposed) {
        _mapNotifier.setError('Error loading map data: $e');
        // Fallback to default view on error
        await _mapboxService.resetCameraView([], null);
      }
    } finally {
      _isLoadingData = false;
      // Ensure loading state is cleared
      if (!_isDisposed) {
        _mapNotifier.setLoadingComplaints(false);
      }
    }
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

          // Reset camera to show all markers
          if (!_isDisposed) {
            await _mapboxService.resetCameraView(markerResult.coordinates, null);
          }
        }
      }
    } catch (e) {
      if (!_isDisposed) {
        _mapNotifier.setError('Error loading map data: $e');
        // Fallback to default view on error
        await _mapboxService.resetCameraView([], null);
      }
    } finally {
      // Ensure loading state is cleared even if there's an error
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
    if (coordinates.isEmpty) return;

    final nextIndex = (state.currentMarkerIndex + 1) % coordinates.length;
    await _flyToMarker(nextIndex);
  }

  Future<void> goToPreviousMarker() async {
    if (_isDisposed) return;
    
    final coordinates = state.complaintCoordinates;
    if (coordinates.isEmpty) return;

    final prevIndex = (state.currentMarkerIndex - 1 + coordinates.length) % coordinates.length;
    await _flyToMarker(prevIndex);
  }

  /// Fly to a specific marker by index
  Future<void> _flyToMarker(int index) async {
    if (_isDisposed) return;
    
    final coordinates = state.complaintCoordinates;
    if (index < 0 || index >= coordinates.length) return;

    final targetCoordinate = coordinates[index];

    try {
      // First zoom out to show overview
      await _mapboxService.resetCameraView(coordinates, null, isBottomSheetVisible: state.isBottomSheetVisible);
      if (_isDisposed) return;
      
      // Wait a bit then zoom in to target
      await Future.delayed(const Duration(milliseconds: 2000));
      if (_isDisposed) return;
      
      await _mapboxService.flyToCoordinate(targetCoordinate);
      if (_isDisposed) return;

      // Update current marker index
      _mapNotifier.setCurrentMarkerIndex(index);
    } catch (e) {
      // Silently ignore fly-to errors
    }
  }

  /// Reset camera view to show all markers
  Future<void> resetCameraView(BuildContext? context) async {
    if (_isDisposed) return;
    
    await _mapboxService.resetCameraView(
      state.complaintCoordinates, 
      context, 
      isBottomSheetVisible: state.isBottomSheetVisible
    );
  }

  /// Handle camera changes (for dynamic marker sizing)
  void onCameraChanged() {
    if (_isDisposed) return;
    
    _mapboxService.setupCameraChangeListener((zoom) {
      if (!_isDisposed) {
        _mapNotifier.setCurrentZoom(zoom);
        _mapboxService.updateMarkerSizes(state.currentAnnotations, zoom);
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
}
