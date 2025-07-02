import 'package:flutter/foundation.dart';
import '../models.dart';
import 'logger.dart';

/// Utility class for offloading heavy data processing to background isolates
/// This prevents UI jank by ensuring main thread remains free for rendering
class BackgroundProcessor {
  
  /// Process complaint marker data in background to prevent UI blocking
  static Future<MarkerProcessingResult> processMarkerData({
    required List<Complaint> complaints,
    required Uint8List imageData,
    double initialIconSize = 0.5,
  }) async {
    // For small datasets, process directly to avoid isolate overhead
    if (complaints.length < 20) {
      return _processMarkersDirectly(complaints, imageData, initialIconSize);
    }
    
    // For larger datasets, use background processing
    final processingData = MarkerProcessingInput(
      complaints: complaints,
      imageData: imageData,
      initialIconSize: initialIconSize,
    );
    
    return await compute(_processMarkersInIsolate, processingData);
  }
  
  /// Process image optimization in background
  static Future<OptimizedImageResult> processImageOptimization({
    required Uint8List imageBytes,
    required String mimeType,
    int? maxWidth,
    int? maxHeight,
    int quality = 85,
  }) async {
    final input = ImageOptimizationInput(
      imageBytes: imageBytes,
      mimeType: mimeType,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      quality: quality,
    );
    
    return await compute(_optimizeImageInIsolate, input);
  }
  
  /// Process large complaint datasets in background
  static Future<List<Complaint>> processComplaintData(List<Map<String, dynamic>> rawData) async {
    // For small datasets, process on main thread to avoid isolate overhead
    if (rawData.length <= 50) {
      return rawData.map((data) {
        final String id = data['id'].toString();
        return Complaint.fromJson(id, data);
      }).toList();
    }
    
    // For larger datasets, use background processing
    return await compute(_parseComplaintsInIsolate, rawData);
  }
  
  /// Direct processing for small datasets (no isolate overhead)
  static MarkerProcessingResult _processMarkersDirectly(
    List<Complaint> complaints, 
    Uint8List imageData, 
    double initialIconSize
  ) {
    final coordinates = <MapPosition>[];
    final markerOptions = <MarkerOption>[];
    final complaintMapping = <String, String>{};
    
    for (int i = 0; i < complaints.length; i++) {
      final complaint = complaints[i];
      final latitude = complaint.latitude;
      final longitude = complaint.longitude;
      
      if (latitude != 0.0 && longitude != 0.0) {
        final position = MapPosition(longitude: longitude, latitude: latitude);
        coordinates.add(position);
        
        final markerOption = MarkerOption(
          position: position,
          imageData: imageData,
          iconSize: initialIconSize,
          complaintId: complaint.id,
        );
        markerOptions.add(markerOption);
        
        // This would need to be mapped to actual annotation IDs later
        complaintMapping['marker_$i'] = complaint.id;
      }
    }
    
    return MarkerProcessingResult(
      coordinates: coordinates,
      markerOptions: markerOptions,
      complaintMapping: complaintMapping,
    );
  }
}

/// Static functions for isolate processing (must be top-level)

/// Process markers in background isolate
MarkerProcessingResult _processMarkersInIsolate(MarkerProcessingInput input) {
  final coordinates = <MapPosition>[];
  final markerOptions = <MarkerOption>[];
  final complaintMapping = <String, String>{};
  
  for (int i = 0; i < input.complaints.length; i++) {
    final complaint = input.complaints[i];
    final latitude = complaint.latitude;
    final longitude = complaint.longitude;
    
    if (latitude != 0.0 && longitude != 0.0) {
      final position = MapPosition(longitude: longitude, latitude: latitude);
      coordinates.add(position);
      
      final markerOption = MarkerOption(
        position: position,
        imageData: input.imageData,
        iconSize: input.initialIconSize,
        complaintId: complaint.id,
      );
      markerOptions.add(markerOption);
      
      complaintMapping['marker_$i'] = complaint.id;
    }
  }
  
  return MarkerProcessingResult(
    coordinates: coordinates,
    markerOptions: markerOptions,
    complaintMapping: complaintMapping,
  );
}

/// Optimize images in background isolate
OptimizedImageResult _optimizeImageInIsolate(ImageOptimizationInput input) {
  // This would contain actual image processing logic
  // For now, return the input as-is with metadata
  return OptimizedImageResult(
    optimizedBytes: input.imageBytes,
    originalSize: input.imageBytes.length,
    optimizedSize: input.imageBytes.length,
    mimeType: input.mimeType,
  );
}

/// Parse complaints in background isolate
List<Complaint> _parseComplaintsInIsolate(List<Map<String, dynamic>> rawData) {
  try {
    return rawData.map((data) {
      final String id = data['id'].toString();
      return Complaint.fromJson(id, data);
    }).toList();
  } catch (e) {
    AppLogger.e('Error parsing complaints in isolate', e);
    return <Complaint>[];
  }
}

/// Input/Output classes for isolate communication

class MarkerProcessingInput {
  final List<Complaint> complaints;
  final Uint8List imageData;
  final double initialIconSize;
  
  MarkerProcessingInput({
    required this.complaints,
    required this.imageData,
    required this.initialIconSize,
  });
}

class MarkerProcessingResult {
  final List<MapPosition> coordinates;
  final List<MarkerOption> markerOptions;
  final Map<String, String> complaintMapping;
  
  MarkerProcessingResult({
    required this.coordinates,
    required this.markerOptions,
    required this.complaintMapping,
  });
}

class MapPosition {
  final double longitude;
  final double latitude;
  
  MapPosition({required this.longitude, required this.latitude});
}

class MarkerOption {
  final MapPosition position;
  final Uint8List imageData;
  final double iconSize;
  final String complaintId;
  
  MarkerOption({
    required this.position,
    required this.imageData,
    required this.iconSize,
    required this.complaintId,
  });
}

class ImageOptimizationInput {
  final Uint8List imageBytes;
  final String mimeType;
  final int? maxWidth;
  final int? maxHeight;
  final int quality;
  
  ImageOptimizationInput({
    required this.imageBytes,
    required this.mimeType,
    this.maxWidth,
    this.maxHeight,
    required this.quality,
  });
}

class OptimizedImageResult {
  final Uint8List optimizedBytes;
  final int originalSize;
  final int optimizedSize;
  final String mimeType;
  
  OptimizedImageResult({
    required this.optimizedBytes,
    required this.originalSize,
    required this.optimizedSize,
    required this.mimeType,
  });
} 