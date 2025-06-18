import 'dart:typed_data';
import 'package:flutter/foundation.dart' show ChangeNotifier, compute;
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:supabase_flutter/supabase_flutter.dart';

// Helper class to hold data prepared for annotations in a separate isolate.
// This class is private as it's only used within this file during data preparation.
class _PreparedAnnotationData {
  final List<mapbox.PointAnnotationOptions> options;
  final Map<String, int> complaintIdToDataIndex;
  // Removed coordinates and optionIndexToComplaintId as they are not directly exposed by the provider,
  // but they are used during the preparation phase.
  // List<mapbox.Position> coordinates;
  // Map<int, String> optionIndexToComplaintId;


  _PreparedAnnotationData({
    required this.options,
    required this.complaintIdToDataIndex,
    // required this.coordinates,
    // required this.optionIndexToComplaintId,
  });
}

// Argument class for the data preparation isolate function.
class _PrepareAnnotationArgs {
  final List<Map<String, dynamic>> complaints;
  // final Uint8List imageData; // Removed: imageData is handled by MapWidget

  _PrepareAnnotationArgs({required this.complaints /*, required this.imageData*/});
}

// Top-level function (or static method) for processing complaint data into annotation options.
// This is designed to be run in a separate isolate using Flutter's compute() function
// to avoid blocking the UI thread with potentially heavy data transformation.
_PreparedAnnotationData _prepareAnnotationOptionsIsolate(_PrepareAnnotationArgs args) {
  final List<Map<String, dynamic>> complaintsData = args.complaints;
  // final Uint8List imageData = args.imageData; // Removed

  final List<mapbox.PointAnnotationOptions> options = [];
  final Map<String, int> complaintIdToDataIndex = {};
  // final List<mapbox.Position> coordinatesList = []; // Kept for internal logic if needed
  // final Map<int, String> optionToComplaintMap = {}; // Kept for internal logic

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
        // image: imageData, // Removed: image string ID will be set by MapWidget before creating annotation
        data: {'complaintId': complaintId},
      ));
      // coordinatesList.add(position);
      // optionToComplaintMap[options.length - 1] = complaintId;
      complaintIdToDataIndex[complaintId] = i;
    }
  }
  return _PreparedAnnotationData(
    options: options,
    complaintIdToDataIndex: complaintIdToDataIndex,
    // coordinates: coordinatesList,
    // optionIndexToComplaintId: optionToComplaintMap,
  );
}

/// ChangeNotifier class responsible for fetching, preparing, and providing
/// map-related complaint data to the UI.
///
/// It fetches raw complaint data from Supabase, processes it into
/// `PointAnnotationOptions` suitable for the `MapWidget`, and manages
/// loading states. UI components can listen to this provider to update
/// when data changes or when loading starts/finishes.
class ComplaintMapDataProvider with ChangeNotifier {
  bool _isLoading = false;
  List<Map<String, dynamic>> _rawComplaintsData = [];
  List<mapbox.PointAnnotationOptions> _annotationOptions = [];
  Map<String, int> _complaintIdToDataIndexMap = {};

  bool get isLoading => _isLoading;
  List<Map<String, dynamic>> get rawComplaintsData => _rawComplaintsData;
  List<mapbox.PointAnnotationOptions> get annotationOptions => _annotationOptions;
  Map<String, int> get complaintIdToDataIndexMap => _complaintIdToDataIndexMap;

  /// Fetches complaint data from the backend (Supabase) and prepares it for map display.
  ///
  /// Sets `isLoading` to true at the start and false at the end.
  /// Notifies listeners after each significant state change (loading start, data ready, error).
  Future<void> fetchAndPrepareComplaints() async {
    if (_isLoading) return; // Prevent concurrent fetches

    _isLoading = true;
    notifyListeners();

    try {
      // debugPrint("ComplaintMapDataProvider: Fetching complaint coordinates..."); // Less verbose
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('complaints')
          .select('id, latitude, longitude, "issueType", status, "imageUrls"')
          .not('latitude', 'is', null)
          .not('longitude', 'is', null);

      // Error handling for Supabase response can be more specific if needed
      // e.g., if (response.error != null) throw response.error!;

      _rawComplaintsData = List<Map<String, dynamic>>.from(response);
      // debugPrint("ComplaintMapDataProvider: Successfully fetched ${_rawComplaintsData.length} complaint entries.");

      if (_rawComplaintsData.isEmpty) {
        _annotationOptions = [];
        _complaintIdToDataIndexMap = {};
        // debugPrint("ComplaintMapDataProvider: No complaints with coordinates found.");
      } else {
        // The `image` property of PointAnnotationOptions will be set by MapWidget
        // before creating the annotation, using the string ID of the image it registers.
        // Thus, the isolate does not need to handle image bytes.
        // debugPrint("ComplaintMapDataProvider: Preparing annotation options in background isolate...");
        final preparedData = await compute<_PrepareAnnotationArgs, _PreparedAnnotationData>(
          _prepareAnnotationOptionsIsolate,
          _PrepareAnnotationArgs(
            complaints: _rawComplaintsData,
          ),
        );

        _annotationOptions = preparedData.options;
        _complaintIdToDataIndexMap = preparedData.complaintIdToDataIndex;

        // debugPrint("ComplaintMapDataProvider: Annotation options preparation complete. Options: ${_annotationOptions.length}, Map: ${_complaintIdToDataIndexMap.length}");
      }
    } catch (e) {
      // In a production app, consider more sophisticated error logging or user feedback.
      debugPrint("ComplaintMapDataProvider: Error fetching or preparing complaint data: $e");
      _rawComplaintsData = []; // Clear data on error
      _annotationOptions = [];
      _complaintIdToDataIndexMap = {};
      // Optionally, set an error message state here for the UI to consume.
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

// Standard debug print function, conditionally prints in debug mode.
void debugPrint(String message) {
  if (kDebugMode) {
    print(message);
  }
}
