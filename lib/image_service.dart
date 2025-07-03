import 'dart:io';
import 'dart:typed_data'; // Required for Uint8List
import 'package:flutter/foundation.dart' show kIsWeb, compute; // Add compute for isolates
// import 'package:firebase_storage/firebase_storage.dart'; // Remove Firebase Storage import
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
// REMOVE Import main to access the supabase getter
// import 'package:ncdc_ccms_app/main.dart'; 
import 'package:mime/mime.dart'; // Import the mime package
import 'package:supabase_flutter/supabase_flutter.dart'; // Import for FileOptions and Exceptions
import 'package:ncdc_ccms_app/utils/logger.dart';
import 'dart:async'; // Add for Completer

class ImageService {
  // Add SupabaseClient field
  final SupabaseClient _supabaseClient;
  final ImagePicker _picker = ImagePicker();
  
  // Cache for image data to avoid re-processing
  final Map<String, Uint8List> _imageCache = {};
  final Map<String, String> _mimeCache = {};
  final Map<String, DateTime> _cacheAccessTimes = {}; // Track access times for LRU eviction

  // PHASE 1: Add throttling mechanism to prevent buffer overflow
  static const int _maxConcurrentOperations = 2; // Reduced from unlimited to prevent buffer overflow
  final List<Completer<void>> _operationQueue = [];
  int _activeOperations = 0;
  bool _disposed = false;

  // PHASE 1: Memory management constants
  static const int _maxCacheItems = 15; // Reduced from 20 to be more conservative
  static const int _maxCacheSizeBytes = 50 * 1024 * 1024; // 50MB cache limit
  int _currentCacheSizeBytes = 0;

  // Constructor accepts and stores the client
  ImageService({required SupabaseClient supabaseClient})
      : _supabaseClient = supabaseClient;

  /// PHASE 1: Throttle operations to prevent ImageReader buffer overflow
  Future<T> _throttleOperation<T>(Future<T> Function() operation) async {
    if (_disposed) {
      throw StateError('ImageService has been disposed');
    }

    // If we're at the limit, wait for a slot
    if (_activeOperations >= _maxConcurrentOperations) {
      final completer = Completer<void>();
      _operationQueue.add(completer);
      await completer.future;
    }

    if (_disposed) {
      throw StateError('ImageService has been disposed');
    }

    _activeOperations++;
    
    try {
      final result = await operation();
      return result;
    } finally {
      _activeOperations--;
      
      // Process next operation in queue
      if (_operationQueue.isNotEmpty && !_disposed) {
        final nextCompleter = _operationQueue.removeAt(0);
        // Use microtask to avoid stack overflow
        scheduleMicrotask(() => nextCompleter.complete());
      }
    }
  }

  /// PHASE 1: LRU eviction strategy
  void _evictLeastRecentlyUsed() {
    if (_imageCache.isEmpty) return;

    // Find the least recently accessed item
    String? oldestKey;
    DateTime? oldestTime;

    for (final entry in _cacheAccessTimes.entries) {
      if (oldestTime == null || entry.value.isBefore(oldestTime)) {
        oldestTime = entry.value;
        oldestKey = entry.key;
      }
    }

    if (oldestKey != null) {
      final imageBytes = _imageCache[oldestKey];
      if (imageBytes != null) {
        _currentCacheSizeBytes -= imageBytes.length;
      }
      
      _imageCache.remove(oldestKey);
      _mimeCache.remove(oldestKey);
      _cacheAccessTimes.remove(oldestKey);
      
      AppLogger.d('[ImageService] Evicted cache entry: $oldestKey (cache size: ${_currentCacheSizeBytes ~/ 1024}KB)');
    }
  }

  /// PHASE 1: Enhanced cache access with memory tracking
  void _recordCacheAccess(String cacheKey) {
    if (_disposed) return;
    _cacheAccessTimes[cacheKey] = DateTime.now();
  }

  /// Process image data in background isolate with throttling
  Future<ImageProcessingResult> _processImageInBackground(XFile file) async {
    if (_disposed) {
      throw StateError('ImageService has been disposed');
    }

    return await _throttleOperation<ImageProcessingResult>(() async {
      final cacheKey = '${file.path}_${file.length}';
      
      // Check cache first and record access
      if (_imageCache.containsKey(cacheKey) && _mimeCache.containsKey(cacheKey)) {
        _recordCacheAccess(cacheKey);
        return ImageProcessingResult(
          bytes: _imageCache[cacheKey]!,
          mimeType: _mimeCache[cacheKey]!,
          fileName: path.basename(file.path),
        );
      }

      ImageProcessingResult result;
      
      try {
        if (kIsWeb) {
          // For web, read bytes directly (can't use isolates with XFile on web)
          final bytes = await file.readAsBytes();
          final mimeType = file.mimeType ?? _detectMimeTypeFromBytes(bytes) ?? 'application/octet-stream';
          
          result = ImageProcessingResult(
            bytes: bytes,
            mimeType: mimeType,
            fileName: path.basename(file.path),
          );
        } else {
          // For mobile, use background isolate
          final imageData = ImageProcessingData(
            filePath: file.path,
            fileName: path.basename(file.path),
            providedMimeType: file.mimeType,
          );
          
          result = await compute(_processImageDataInIsolate, imageData);
        }

        // PHASE 1: Enhanced caching with memory management
        if (!_disposed && result.bytes.isNotEmpty) {
          // Check if we have room for this item
          final newItemSize = result.bytes.length;
          
          // Pre-emptively clear cache if this item would exceed limits
          while ((_imageCache.length >= _maxCacheItems || 
                  _currentCacheSizeBytes + newItemSize > _maxCacheSizeBytes) &&
                 _imageCache.isNotEmpty) {
            _evictLeastRecentlyUsed();
          }
          
          // Cache the result if we have room
          if (_imageCache.length < _maxCacheItems && 
              _currentCacheSizeBytes + newItemSize <= _maxCacheSizeBytes) {
            _imageCache[cacheKey] = result.bytes;
            _mimeCache[cacheKey] = result.mimeType;
            _recordCacheAccess(cacheKey);
            _currentCacheSizeBytes += newItemSize;
            
            AppLogger.d('[ImageService] Cached image: ${result.fileName} (${newItemSize ~/ 1024}KB, total: ${_currentCacheSizeBytes ~/ 1024}KB)');
          } else {
            AppLogger.w('[ImageService] Cannot cache ${result.fileName}: would exceed memory limits');
          }
        }
        
        return result;
      } catch (e) {
        AppLogger.e('[ImageService] Error processing image: ${file.path}', e);
        // Return empty result on error to prevent cascading failures
        return ImageProcessingResult(
          bytes: Uint8List(0),
          mimeType: 'application/octet-stream',
          fileName: path.basename(file.path),
        );
      }
    });
  }

  /// Optimized upload with background processing and enhanced error handling
  Future<List<String>> uploadImages(List<XFile> files, String complaintId) async {
    if (_disposed) {
      throw StateError('ImageService has been disposed');
    }

    if (files.isEmpty) {
      return [];
    }

    List<String> downloadUrls = [];
    const String bucketName = 'complaintimages';

    try {
      // PHASE 1: Process images with throttling to prevent buffer overflow
      AppLogger.d('[ImageService] Processing ${files.length} images with throttling...');
      
      // Process images in smaller batches to prevent memory spikes
      final batchSize = _maxConcurrentOperations;
      final List<ImageProcessingResult> allResults = [];
      
      for (int i = 0; i < files.length; i += batchSize) {
        if (_disposed) break;
        
        final endIndex = (i + batchSize < files.length) ? i + batchSize : files.length;
        final batch = files.sublist(i, endIndex);
        
        final batchFutures = batch.map((file) => _processImageInBackground(file)).toList();
        final batchResults = await Future.wait(batchFutures);
        allResults.addAll(batchResults);
        
        // Small delay between batches to allow other operations
        if (endIndex < files.length && !_disposed) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }

      // Upload processed images
      for (int i = 0; i < files.length && i < allResults.length; i++) {
        if (_disposed) break;
        
        final file = files[i];
        final result = allResults[i];
        
        // Skip empty results (failed processing)
        if (result.bytes.isEmpty) {
          AppLogger.w('[ImageService] Skipping upload for failed image processing: ${result.fileName}');
          continue;
        }
        
        final String storagePath = '/complaints/$complaintId/images/${result.fileName}';

        try {
          if (kIsWeb) {
            AppLogger.d('[ImageService] Uploading Web: path=$storagePath, contentType=${result.mimeType}');
            await _supabaseClient.storage.from(bucketName).uploadBinary(
                  storagePath,
                  result.bytes,
                  fileOptions: FileOptions(contentType: result.mimeType, upsert: false),
                );
          } else {
            final File fileObject = File(file.path);
             await _supabaseClient.storage.from(bucketName).upload(
                  storagePath,
                  fileObject,
                  fileOptions: FileOptions(contentType: result.mimeType, upsert: false),
                );
          }

          // Sanitize path before getting URL
          final sanitizedPathForUrl = storagePath.replaceAll(RegExp(r'^/+'), '').replaceAll(RegExp(r'/+$'), '');

          final String downloadUrl = _supabaseClient.storage.from(bucketName).getPublicUrl(sanitizedPathForUrl);
          AppLogger.d('[ImageService] Got Public URL: $downloadUrl (from path: $sanitizedPathForUrl)');
          downloadUrls.add(downloadUrl);
        } on StorageException catch (e) {
          String errorMsg = 'Storage Error during upload for ${result.fileName}: ${e.message}';
          if (e.statusCode == '401' || e.statusCode == '403') {
              errorMsg += '\n(Check Storage RLS Policies for authenticated uploads)';
          } else if (e.message.contains('Bucket not found')) {
              errorMsg += '\n(Verify bucket "$bucketName" exists)';
          }
          AppLogger.e(errorMsg, e);
          AppLogger.e('Storage Error Details: ${e.toString()}');
        } catch (e) {
          AppLogger.e('Unexpected error during upload process for ${result.fileName}', e);
          AppLogger.e('Unexpected Error Details: ${e.toString()}');
        }
      }

      return downloadUrls;
    } catch (e) {
      AppLogger.e('[ImageService] Critical error in uploadImages', e);
      return downloadUrls; // Return partial results rather than failing completely
    }
  }

  /// Get processed image data for preview (with caching and throttling)
  Future<Uint8List> getImageBytes(XFile file) async {
    final result = await _processImageInBackground(file);
    return result.bytes;
  }

  /// Get MIME type for file (with caching and throttling)
  Future<String> getMimeType(XFile file) async {
    final result = await _processImageInBackground(file);
    return result.mimeType;
  }

  /// Detect MIME type from bytes (fallback)
  String? _detectMimeTypeFromBytes(Uint8List bytes) {
    if (bytes.length < 4) return null;
    
    // Check for common image signatures
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'image/jpeg';
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return 'image/png';
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return 'image/gif';
    if (bytes[0] == 0x57 && bytes[1] == 0x45 && bytes[2] == 0x42 && bytes[3] == 0x50) return 'image/webp';
    
    return null;
  }

  Future<List<XFile>> pickImages() async {
    final List<XFile> pickedFiles = await _picker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    return pickedFiles;
  }

  Future<XFile?> takePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    return photo;
  }

  /// PHASE 1: Enhanced cache clearing with memory tracking
  void clearCache() {
    if (_disposed) return;
    
    final clearedSize = _currentCacheSizeBytes;
    _imageCache.clear();
    _mimeCache.clear();
    _cacheAccessTimes.clear();
    _currentCacheSizeBytes = 0;
    
    AppLogger.d('[ImageService] Cache cleared: freed ${clearedSize ~/ 1024}KB');
  }

  /// PHASE 1: Clear cache under memory pressure
  void clearCacheUnderPressure() {
    if (_disposed) return;
    
    AppLogger.w('[ImageService] Clearing cache due to memory pressure');
    
    // Clear half the cache by removing oldest entries
    final targetSize = _imageCache.length ~/ 2;
    while (_imageCache.length > targetSize && _imageCache.isNotEmpty) {
      _evictLeastRecentlyUsed();
    }
  }

  /// PHASE 1: Get current cache usage information
  Map<String, dynamic> getCacheInfo() {
    return {
      'cacheItems': _imageCache.length,
      'cacheSizeBytes': _currentCacheSizeBytes,
      'cacheSizeKB': _currentCacheSizeBytes ~/ 1024,
      'maxCacheItems': _maxCacheItems,
      'maxCacheSizeBytes': _maxCacheSizeBytes,
      'activeOperations': _activeOperations,
      'queuedOperations': _operationQueue.length,
      'isDisposed': _disposed,
    };
  }

  /// Create optimized thumbnail for preview (reduces memory usage) with throttling
  Future<Uint8List> getThumbnailBytes(XFile file, {int maxWidth = 200, int maxHeight = 200}) async {
    // For now, we'll use the full image processing but this could be extended
    // to create actual thumbnails using image processing libraries like 'image' package
    final result = await _processImageInBackground(file);
    return result.bytes;
  }

  /// PHASE 1: Enhanced disposal with proper cleanup
  void dispose() {
    if (_disposed) return;
    
    AppLogger.d('[ImageService] Disposing ImageService...');
    
    _disposed = true;
    
    // Cancel all queued operations
    for (final completer in _operationQueue) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('ImageService disposed'));
      }
    }
    _operationQueue.clear();
    
    // Clear cache and reset counters
    clearCache();
    _activeOperations = 0;
    
    AppLogger.d('[ImageService] ImageService disposed successfully');
  }
}

/// Data class for passing to isolate
class ImageProcessingData {
  final String filePath;
  final String fileName;
  final String? providedMimeType;

  ImageProcessingData({
    required this.filePath,
    required this.fileName,
    this.providedMimeType,
  });
}

/// Result class for processed image data
class ImageProcessingResult {
  final Uint8List bytes;
  final String mimeType;
  final String fileName;

  ImageProcessingResult({
    required this.bytes,
    required this.mimeType,
    required this.fileName,
  });
}

/// Static function to process image data in isolate
ImageProcessingResult _processImageDataInIsolate(ImageProcessingData data) {
  try {
    final file = File(data.filePath);
    final bytes = file.readAsBytesSync();
    
    // Determine MIME type
    String mimeType = data.providedMimeType ?? 
                      lookupMimeType(data.fileName, headerBytes: bytes.length > 1024 ? bytes.sublist(0, 1024) : bytes) ?? 
                      'application/octet-stream';
    
    return ImageProcessingResult(
      bytes: bytes,
      mimeType: mimeType,
      fileName: data.fileName,
    );
  } catch (e) {
    AppLogger.e('Error processing image in isolate', e);
    // Return empty result on error
    return ImageProcessingResult(
      bytes: Uint8List(0),
      mimeType: 'application/octet-stream',
      fileName: data.fileName,
    );
  }
}