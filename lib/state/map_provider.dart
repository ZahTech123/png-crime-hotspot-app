import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox; // Ensure mapbox import if Position is used

// Minimal MapProvider for now, to be expanded
class MapProvider with ChangeNotifier {
  bool _isLoadingComplaints = true;
  bool get isLoadingComplaints => _isLoadingComplaints;

  List<Map<String, dynamic>> _complaintsData = [];
  List<Map<String, dynamic>> get complaintsData => _complaintsData;

  List<mapbox.Position> _complaintCoordinates = [];
  List<mapbox.Position> get complaintCoordinates => _complaintCoordinates;

  List<mapbox.PointAnnotation> _currentAnnotations = [];
  List<mapbox.PointAnnotation> get currentAnnotations => _currentAnnotations;

  Map<String, String> _annotationIdToComplaintId = {};
  Map<String, String> get annotationIdToComplaintId => _annotationIdToComplaintId;

  Map<String, int> _complaintIdToDataIndex = {};
  Map<String, int> get complaintIdToDataIndex => _complaintIdToDataIndex;

  int? _selectedComplaintIndex;
  int? get selectedComplaintIndex => _selectedComplaintIndex;

  PageController? _pageController;
  PageController? get pageController => _pageController;


  void setLoadingComplaints(bool loading) {
    _isLoadingComplaints = loading;
    notifyListeners();
  }

  void setComplaintsData(List<Map<String, dynamic>> data, List<mapbox.Position> coordinates) {
    _complaintsData = data;
    _complaintCoordinates = coordinates;
    _isLoadingComplaints = false; // Typically set to false when data arrives
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

  void initPageController() {
    if (_pageController == null || !_pageController!.hasClients) { // Check if null or if current has no clients
        _pageController = PageController(viewportFraction: 0.85);
         // notifyListeners(); // Usually not needed for controller init unless UI depends on its existence
    }
  }

  void disposePageController() {
    _pageController?.dispose();
    _pageController = null; // Explicitly set to null
  }

  // Add other state properties and methods as identified previously as needed
  // For example: isMapControllerReady, isStyleLoaded, currentZoom, etc.
}
