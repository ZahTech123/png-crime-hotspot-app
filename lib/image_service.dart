import 'dart:io';
import 'dart:typed_data'; // Required for Uint8List
import 'package:flutter/foundation.dart' show kIsWeb; // Required for kIsWeb
// import 'package:firebase_storage/firebase_storage.dart'; // Remove Firebase Storage import
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
// REMOVE Import main to access the supabase getter
// import 'package:ncdc_ccms_app/main.dart'; 
import 'package:mime/mime.dart'; // Import the mime package
import 'package:supabase_flutter/supabase_flutter.dart'; // Import for FileOptions and Exceptions

class ImageService {
  // Add SupabaseClient field
  final SupabaseClient _supabaseClient;
  final ImagePicker _picker = ImagePicker();

  // Constructor accepts and stores the client
  ImageService({required SupabaseClient supabaseClient})
      : _supabaseClient = supabaseClient;

  Future<List<String>> uploadImages(List<XFile> files, String complaintId) async {
    List<String> downloadUrls = [];
    const String bucketName = 'complaintimages'; // Define Supabase bucket name

    for (var file in files) {
      final String fileName = path.basename(file.path);
      final String storagePath = '/complaints/$complaintId/images/$fileName'; // Path within the bucket
      
      // Prioritize XFile.mimeType, then lookupMimeType, then fallback
      final String contentType = file.mimeType ?? 
                               lookupMimeType(fileName) ?? 
                               'application/octet-stream';

      try {
        if (kIsWeb) {
          print('[ImageService] Uploading Web: path=$storagePath, contentType=$contentType');
          final Uint8List fileBytes = await file.readAsBytes();
          await _supabaseClient.storage.from(bucketName).uploadBinary(
                storagePath,
                fileBytes,
                fileOptions: FileOptions(contentType: contentType, upsert: false),
              );
        } else {
          final File fileObject = File(file.path);
           await _supabaseClient.storage.from(bucketName).upload(
                storagePath,
                fileObject,
                fileOptions: FileOptions(contentType: contentType, upsert: false),
              );
        }

        // Sanitize path before getting URL
        final sanitizedPathForUrl = storagePath.replaceAll(RegExp(r'^/+'), '').replaceAll(RegExp(r'/+$'), '');

        final String downloadUrl = _supabaseClient.storage.from(bucketName).getPublicUrl(sanitizedPathForUrl);
        print('[ImageService] Got Public URL: $downloadUrl (from path: $sanitizedPathForUrl)'); // Log sanitized path
        downloadUrls.add(downloadUrl);
      } on StorageException catch (e) {
        String errorMsg = 'Storage Error during upload for $fileName: ${e.message}';
        if (e.statusCode == '401' || e.statusCode == '403') {
            errorMsg += '\n(Check Storage RLS Policies for authenticated uploads)';
        } else if (e.message.contains('Bucket not found')) {
            errorMsg += '\n(Verify bucket "$bucketName" exists)';
        }
        print(errorMsg);
        print('Storage Error Details: ${e.toString()}');
      } catch (e) {
        print('Unexpected error during upload process for $fileName: $e');
        print('Unexpected Error Details: ${e.toString()}');
      }
    }

    return downloadUrls;
  }

  Future<List<XFile>> pickImages() async {
    final List<XFile> pickedFiles = await _picker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    // Use ?? [] to handle null case gracefully
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
}