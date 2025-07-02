import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For rootBundle
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:provider/provider.dart';
import '../complaint_provider.dart';
import '../models.dart'; // For Complaint model
import '../providers/performance_provider.dart';
import '../utils/background_processor.dart';
import '../utils/logger.dart';
import 'map_controller.dart';
import 'map_state.dart';
import 'mapbox_service.dart';
import 'widgets/map_controls.dart';
import 'widgets/persistent_bottom_sheet.dart';
import 'widgets/safe_mapbox_widget.dart';

/// MapScreen using the new clean architecture with FutureBuilder pattern and performance optimization
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with PerformanceAware {
  // Services and controllers
  late final MapNotifier _mapNotifier;
  late final MapboxService _mapboxService;
  late final MapController _mapController;
  
  // Mapbox access token
  final String _mapboxAccessToken = 'pk.eyJ1Ijoiam9obnNraXBvbGkiLCJhIjoiY201c3BzcDYxMG9neDJscTZqeXQ4MGk4YSJ9.afrO8Lq1P6mIUbSyQ6VCsQ';

  @override
  void initState() {
    super.initState();
    
    // Set Mapbox access token immediately
    if (_mapboxAccessToken.isNotEmpty && _mapboxAccessToken.startsWith('pk.')) {
      mapbox.MapboxOptions.setAccessToken(_mapboxAccessToken);
    }

    // Initialize services and controllers synchronously
    _mapNotifier = MapNotifier();
    _mapboxService = MapboxService();
    
    // Get ComplaintService from ComplaintProvider (same as other screens)
    final complaintService = Provider.of<ComplaintProvider>(context, listen: false).complaintService;
    
    _mapController = MapController(
      mapNotifier: _mapNotifier,
      mapboxService: _mapboxService,
      complaintService: complaintService,
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    _mapNotifier.dispose();
    super.dispose();
  }



  /// Handle map creation with performance optimization
  void _onMapCreated(mapbox.MapboxMap mapboxMap) async {
    if (!mounted) return;
    
    final performanceProvider = Provider.of<PerformanceProvider>(context, listen: false);
    
    try {
      // Set map loading state
      performanceProvider.setMapLoading(true);
      
      // Only do immediate, non-blocking map setup here
      await _mapController.initializeMapSync(mapboxMap);
      
      // Start data loading asynchronously using background processor
      if (mounted && performanceProvider.enableBackgroundProcessing) {
        _loadDataWithBackgroundProcessing();
      } else if (mounted) {
        // Fallback to standard loading if background processing is disabled
        _mapController.loadComplaintDataAsync();
      }
    } catch (e) {
      performanceProvider.setError('Error initializing map: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing map: $e')),
        );
      }
    } finally {
      performanceProvider.setMapLoading(false);
    }
  }

  /// Load data using background processor for optimal performance
  void _loadDataWithBackgroundProcessing() async {
    final performanceProvider = Provider.of<PerformanceProvider>(context, listen: false);
    final complaintService = Provider.of<ComplaintProvider>(context, listen: false).complaintService;
    
    try {
      // Set data loading state
      performanceProvider.setDataLoading(true);
      
      // Fetch complaints using background processing
      final complaints = await complaintService.getComplaintsForMap();
      
      if (!mounted) return;
      
      if (complaints.isNotEmpty) {
        // Use background processor for marker processing if performance mode allows
        if (performanceProvider.enableBackgroundProcessing && 
            complaints.length >= 10) { // Use threshold for background processing
          
          AppLogger.d('[MapScreen] Processing ${complaints.length} markers in background');
          
          // Load marker image data
          final imageData = await rootBundle.load('assets/map-point.png');
          final imageBytes = imageData.buffer.asUint8List();
          
          // Process markers in background
          final markerResult = await BackgroundProcessor.processMarkerData(
            complaints: complaints,
            imageData: imageBytes,
            initialIconSize: 0.5,
          );
          
          if (!mounted) return;
          
          // Apply the processed markers to the map
          _applyProcessedMarkers(markerResult, complaints);
          
        } else {
          // Use standard processing for small datasets
          _mapController.loadComplaintDataAsync();
        }
      }
      
    } catch (e) {
      if (mounted) {
        performanceProvider.setError('Error loading map data: $e');
      }
    } finally {
      if (mounted) {
        performanceProvider.setDataLoading(false);
      }
    }
  }

  /// Apply processed markers to the map
  void _applyProcessedMarkers(MarkerProcessingResult result, List<Complaint> complaints) {
    // Update map state with processed data
    _mapNotifier.setComplaints(complaints);
    
    // This would need to be coordinated with the MapboxService
    // For now, fall back to standard processing
    _mapController.loadComplaintDataAsync();
  }

  /// Handle style loaded event
  void _onStyleLoadedCallback(mapbox.StyleLoadedEventData data) {
    // Style configuration is now handled by MapboxService
    // Additional style customizations can be added here if needed
  }

  /// Handle camera change events with performance monitoring
  void _onCameraChanged(mapbox.CameraChangedEventData event) {
    final performanceProvider = Provider.of<PerformanceProvider>(context, listen: false);
    
    // Record frame timing for performance monitoring
    performanceProvider.recordFrameTime();
    
    _mapController.onCameraChanged();
  }

  /// Prepare for navigation (cleanup)
  void _prepareForNavigation() {
    _mapController.clearData();
  }

  @override
  Widget build(BuildContext context) {
    startBuildTiming(); // Start performance monitoring
    
    // Check token validity
    if (_mapboxAccessToken.isEmpty || !_mapboxAccessToken.startsWith('pk.')) {
      endBuildTiming('MapScreen (Error)');
      return _buildErrorScreen('Mapbox Access Token is invalid or missing. Please provide a valid token.');
    }

    final widget = PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _prepareForNavigation();
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        body: _buildMapBody(),
      ),
    );
    
    endBuildTiming('MapScreen'); // End performance monitoring
    return widget;
  }

  /// Build the app bar with logo and title
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/NCDC Logo.png',
            height: 30,
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
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
    );
  }

  /// Build the main map body with controls and overlays
  Widget _buildMapBody() {
    return ChangeNotifierProvider.value(
      value: _mapNotifier,
      child: Stack(
        children: [
          // Map widget
          SafeMapboxWidget(
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: _onStyleLoadedCallback,
            onCameraChangeListener: _onCameraChanged,
            cameraOptions: mapbox.CameraOptions(
              center: mapbox.Point(coordinates: mapbox.Position(147.1803, -9.4438)),
              pitch: 45.0,
              zoom: 16.0,
              bearing: 0.0,
            ),
            styleUri: mapbox.MapboxStyles.STANDARD,
            textureView: true,
          ),

          // Map controls
          Consumer<MapNotifier>(
            builder: (context, mapNotifier, child) {
              return MapControls(
                onResetView: () => _mapController.resetCameraView(context),
                onZoomIn: _mapController.zoomIn,
                onZoomOut: _mapController.zoomOut,
                onRotateLeft: _mapController.rotateLeft,
                onRotateRight: _mapController.rotateRight,
                onIncreasePitch: _mapController.increasePitch,
                onDecreasePitch: _mapController.decreasePitch,
                onPreviousMarker: _mapController.goToPreviousMarker,
                onNextMarker: _mapController.goToNextMarker,
                canNavigateMarkers: mapNotifier.complaintCoordinates.isNotEmpty,
                bottomPadding: mapNotifier.isBottomSheetVisible ? 200.0 : 0.0,
              );
            },
          ),

          // Bottom sheet carousel
          Consumer<MapNotifier>(
            builder: (context, mapNotifier, child) {
              return MapBottomCarousel(
                complaintsData: mapNotifier.selectedComplaintsData,
                onClose: _mapController.hideComplaintDetails,
                isVisible: mapNotifier.isBottomSheetVisible,
                onLocationChange: _mapController.onCarouselLocationChange,
                initialIndex: mapNotifier.selectedComplaintIndex,
              );
            },
          ),

          // Loading indicator
          Consumer<MapNotifier>(
            builder: (context, mapNotifier, child) {
              if (!mapNotifier.isLoadingComplaints) return const SizedBox.shrink();
              
              return const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text('Loading complaints...'),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Error display
          Consumer<MapNotifier>(
            builder: (context, mapNotifier, child) {
              final error = mapNotifier.errorMessage;
              if (error == null) return const SizedBox.shrink();
              
              return Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Card(
                  color: Colors.red.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            error,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => _mapNotifier.clearError(),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Build error screen for invalid token
  Widget _buildErrorScreen(String message) {
    return Scaffold(
      appBar: AppBar(title: const Text("Map Error")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 