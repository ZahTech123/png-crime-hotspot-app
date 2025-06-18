import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox; // For PointAnnotation, Position
import 'package:flutter/foundation.dart'; // For ChangeNotifier

class MapProvider with ChangeNotifier {
  bool _isLoadingComplaints = true;
  bool _isMapControllerReady = false;
  bool _isStyleLoaded = false;
  List<Map<String, dynamic>> _complaintsData = [];
  List<mapbox.Position> _complaintCoordinates = [];
  List<mapbox.PointAnnotation> _currentAnnotations = [];
  Map<String, String> _annotationIdToComplaintId = {};
  Map<String, int> _complaintIdToDataIndex = {};
  int? _selectedComplaintIndex;
  double _currentZoom = 12.0;
  PageController? _pageController = PageController(viewportFraction: 0.85);

  // Getters
  bool get isLoadingComplaints => _isLoadingComplaints;
  bool get isMapControllerReady => _isMapControllerReady;
  bool get isStyleLoaded => _isStyleLoaded;
  List<Map<String, dynamic>> get complaintsData => _complaintsData;
  List<mapbox.Position> get complaintCoordinates => _complaintCoordinates;
  List<mapbox.PointAnnotation> get currentAnnotations => _currentAnnotations;
  Map<String, String> get annotationIdToComplaintId => _annotationIdToComplaintId;
  Map<String, int> get complaintIdToDataIndex => _complaintIdToDataIndex;
  int? get selectedComplaintIndex => _selectedComplaintIndex;
  double get currentZoom => _currentZoom;
  PageController? get pageController => _pageController;

  bool get canDisplayMap => _isMapControllerReady && _isStyleLoaded;

  // Methods
  void setLoadingComplaints(bool loading) {
    _isLoadingComplaints = loading;
    notifyListeners();
  }

  void setMapControllerReady(bool ready) {
    _isMapControllerReady = ready;
    notifyListeners();
  }

  void setStyleLoaded(bool loaded) {
    _isStyleLoaded = loaded;
    notifyListeners();
  }

  void setComplaintsData(List<Map<String, dynamic>> data, List<mapbox.Position> coordinates) {
    _complaintsData = data;
    _complaintCoordinates = coordinates;
    _isLoadingComplaints = false; // Typically, when data is set, loading is finished.
    notifyListeners();
  }

  void setAnnotations(List<mapbox.PointAnnotation> annotations, Map<String, String> annIdToComplaintId, Map<String, int> compIdToDataIdx) {
    _currentAnnotations = annotations;
    _annotationIdToComplaintId = annIdToComplaintId;
    _complaintIdToDataIndex = compIdToDataIdx;
    notifyListeners();
  }

  void setSelectedComplaintIndex(int? index) {
    _selectedComplaintIndex = index;
    if (index != null && _pageController != null && _pageController!.hasClients) {
      _pageController!.animateToPage(
        index,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    }
    notifyListeners();
  }

  void setCurrentZoom(double zoom) {
    _currentZoom = zoom;
    notifyListeners();
  }

  void initPageController() {
    if (_pageController == null) { // Check if it's null, not if it has clients
      _pageController = PageController(viewportFraction: 0.85);
      notifyListeners(); // Notify if you want UI to react to a new controller instance
    }
  }

  void disposePageController() {
    _pageController?.dispose();
    _pageController = null;
    // No notifyListeners() needed here typically, as dispose is for cleanup.
  }

  // Ensure to call super.dispose() if you override dispose in MapProvider itself
  @override
  void dispose() {
    disposePageController(); // Dispose the page controller
    super.dispose();
  }
}
