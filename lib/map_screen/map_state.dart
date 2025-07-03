import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import '../models.dart';

/// Represents the current state of the map screen
class MapState {
  final List<Complaint> complaints;
  final bool isLoadingComplaints;
  final String? errorMessage;
  final List<mapbox.Position> complaintCoordinates;
  final int currentMarkerIndex;
  final bool isBottomSheetVisible;
  final List<Complaint>? selectedComplaintsData;
  final int? selectedComplaintIndex;
  final double currentZoom;
  final List<mapbox.PointAnnotation> currentAnnotations;
  final Map<String, String> annotationIdToComplaintId;
  final bool isDarkMode; // Added for theme switching

  const MapState({
    this.complaints = const [],
    this.isLoadingComplaints = false,
    this.errorMessage,
    this.complaintCoordinates = const [],
    this.currentMarkerIndex = -1,
    this.isBottomSheetVisible = false,
    this.selectedComplaintsData,
    this.selectedComplaintIndex,
    this.currentZoom = 12.0,
    this.currentAnnotations = const [],
    this.annotationIdToComplaintId = const {},
    this.isDarkMode = false, // Default to light mode
  });

  MapState copyWith({
    List<Complaint>? complaints,
    bool? isLoadingComplaints,
    String? errorMessage,
    List<mapbox.Position>? complaintCoordinates,
    int? currentMarkerIndex,
    bool? isBottomSheetVisible,
    List<Complaint>? selectedComplaintsData,
    int? selectedComplaintIndex,
    double? currentZoom,
    List<mapbox.PointAnnotation>? currentAnnotations,
    Map<String, String>? annotationIdToComplaintId,
    bool? isDarkMode, // Added for theme switching
  }) {
    return MapState(
      complaints: complaints ?? this.complaints,
      isLoadingComplaints: isLoadingComplaints ?? this.isLoadingComplaints,
      errorMessage: errorMessage ?? this.errorMessage,
      complaintCoordinates: complaintCoordinates ?? this.complaintCoordinates,
      currentMarkerIndex: currentMarkerIndex ?? this.currentMarkerIndex,
      isBottomSheetVisible: isBottomSheetVisible ?? this.isBottomSheetVisible,
      selectedComplaintsData: selectedComplaintsData ?? this.selectedComplaintsData,
      selectedComplaintIndex: selectedComplaintIndex ?? this.selectedComplaintIndex,
      currentZoom: currentZoom ?? this.currentZoom,
      currentAnnotations: currentAnnotations ?? this.currentAnnotations,
      annotationIdToComplaintId: annotationIdToComplaintId ?? this.annotationIdToComplaintId,
      isDarkMode: isDarkMode ?? this.isDarkMode, // Added for theme switching
    );
  }

  /// Clear error message
  MapState clearError() {
    return copyWith(errorMessage: null);
  }

  /// Reset bottom sheet state
  MapState hideBottomSheet() {
    return copyWith(
      isBottomSheetVisible: false,
      selectedComplaintsData: null,
      selectedComplaintIndex: null,
    );
  }

  /// Clear all map markers and coordinates
  MapState clearMarkers() {
    return copyWith(
      complaintCoordinates: [],
      currentMarkerIndex: -1,
      currentAnnotations: [],
      annotationIdToComplaintId: {},
    );
  }
}

/// Notifier class to manage map state changes
class MapNotifier extends ChangeNotifier {
  MapState _state = const MapState();
  
  MapState get state => _state;
  
  // Getters for commonly accessed state properties
  List<Complaint> get complaints => _state.complaints;
  bool get isLoadingComplaints => _state.isLoadingComplaints;
  String? get errorMessage => _state.errorMessage;
  List<mapbox.Position> get complaintCoordinates => _state.complaintCoordinates;
  int get currentMarkerIndex => _state.currentMarkerIndex;
  bool get isBottomSheetVisible => _state.isBottomSheetVisible;
  List<Complaint>? get selectedComplaintsData => _state.selectedComplaintsData;
  int? get selectedComplaintIndex => _state.selectedComplaintIndex;
  double get currentZoom => _state.currentZoom;
  List<mapbox.PointAnnotation> get currentAnnotations => _state.currentAnnotations;
  Map<String, String> get annotationIdToComplaintId => _state.annotationIdToComplaintId;
  bool get isDarkMode => _state.isDarkMode; // Getter for isDarkMode

  /// Update the entire state
  void updateState(MapState newState) {
    _state = newState;
    notifyListeners();
  }

  /// Set loading state for complaints
  void setLoadingComplaints(bool isLoading) {
    _state = _state.copyWith(isLoadingComplaints: isLoading);
    notifyListeners();
  }

  /// Set complaints data
  void setComplaints(List<Complaint> complaints) {
    _state = _state.copyWith(
      complaints: complaints,
      isLoadingComplaints: false,
      errorMessage: null,
    );
    notifyListeners();
  }

  /// Set error message
  void setError(String error) {
    _state = _state.copyWith(
      errorMessage: error,
      isLoadingComplaints: false,
    );
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _state = _state.clearError();
    notifyListeners();
  }

  /// Update complaint coordinates and related data
  void setComplaintCoordinates({
    required List<mapbox.Position> coordinates,
    required List<mapbox.PointAnnotation> annotations,
    required Map<String, String> annotationMapping,
  }) {
    _state = _state.copyWith(
      complaintCoordinates: coordinates,
      currentAnnotations: annotations,
      annotationIdToComplaintId: annotationMapping,
      currentMarkerIndex: coordinates.isNotEmpty ? 0 : -1,
    );
    notifyListeners();
  }

  /// Update current marker index
  void setCurrentMarkerIndex(int index) {
    _state = _state.copyWith(currentMarkerIndex: index);
    notifyListeners();
  }

  /// Update current zoom level
  void setCurrentZoom(double zoom) {
    _state = _state.copyWith(currentZoom: zoom);
    notifyListeners();
  }

  /// Update annotations (for dynamic sizing)
  void updateAnnotations(List<mapbox.PointAnnotation> annotations) {
    _state = _state.copyWith(currentAnnotations: annotations);
    notifyListeners();
  }

  /// Show bottom sheet with complaint details
  void showBottomSheet({
    required List<Complaint>? complaintsData,
    int? selectedIndex,
  }) {
    _state = _state.copyWith(
      isBottomSheetVisible: true,
      selectedComplaintsData: complaintsData,
      selectedComplaintIndex: selectedIndex ?? 0,
    );
    notifyListeners();
  }

  /// Hide bottom sheet
  void hideBottomSheet() {
    _state = _state.hideBottomSheet();
    notifyListeners();
  }

  /// Clear all markers and reset related state
  void clearMarkers() {
    _state = _state.clearMarkers();
    notifyListeners();
  }

  /// Toggle dark mode
  void toggleDarkMode() {
    _state = _state.copyWith(isDarkMode: !_state.isDarkMode);
    notifyListeners();
  }

  /// Reset the entire state to initial values
  void reset() {
    _state = const MapState();
    notifyListeners();
  }

  /// Dispose resources and cleanup
  @override
  void dispose() {
    // Clear all data to free memory
    _state = const MapState();
    
    // Call parent dispose to cleanup listeners
    super.dispose();
  }
}
