import 'dart:io'; // Needed for File type in previews
import 'dart:typed_data'; // Needed for Uint8List for web preview
import 'package:flutter/foundation.dart' show kIsWeb; // Import kIsWeb
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Import XFile
import 'models.dart';
import 'complaint_provider.dart';
import 'image_service.dart';
import 'utils/responsive.dart'; // Import the Responsive helper
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart'; // For guessing MIME types
import 'package:path/path.dart' as path; // Import path package

class EditComplaintDialog extends StatefulWidget {
  final CityComplaint complaint;
  final ComplaintProvider complaintProvider;
  final ImageService imageService;

  const EditComplaintDialog({
    super.key,
    required this.complaint,
    required this.complaintProvider,
    required this.imageService,
  });

  @override
  State<EditComplaintDialog> createState() => _EditComplaintDialogState();
}

class _EditComplaintDialogState extends State<EditComplaintDialog> {
  final formKey = GlobalKey<FormState>();
  late TextEditingController descriptionController;
  String status = 'In Progress'; // Default value

  // State for newly selected/taken images/files
  XFile? _mainImageToUpload; // For the main photo taken with camera
  List<PlatformFile> _newlySelectedImages = []; // For attachments from file picker
  bool _mainImageMarkedForRemoval = false; // Flag to track main image removal

  bool _isUploading = false; // Combined loading state for update + upload

  @override
  void initState() {
    super.initState();
    descriptionController = TextEditingController(); // Initialize with empty text
    // Set initial status, defaulting to 'In Progress' if current status is invalid
    if (widget.complaint.status == 'In Progress' || widget.complaint.status == 'Resolved') {
      status = widget.complaint.status;
    } else {
      status = 'In Progress'; // Default for 'New', 'Closed', etc.
    }
    // If you want to pre-populate the description:
    descriptionController = TextEditingController(text: widget.complaint.description);
  }

  // --- Image Picking Methods ---

  // Updated to use file_picker for attachments (PDF, PNG, JPG)
  Future<void> _pickImages() async {
    try {
      // Use file_picker to select multiple files
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          // Add picked files (PlatformFile) to the list
          _newlySelectedImages.addAll(result.files);
        });
      } else {
        // User canceled the picker
        print('User canceled file picking');
      }
    } catch (e) {
      print('Error picking files: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking files: $e'))
      );
    }
  }

  // Updated to set the _mainImageToUpload for main preview
  Future<void> _takePhoto() async {
    try {
      // Still use image_picker for taking a photo
      final XFile? photo = await widget.imageService.takePhoto();
      if (photo != null) {
        setState(() {
          // Set this photo as the main image to upload/preview
          _mainImageToUpload = photo;
          _mainImageMarkedForRemoval = false; // Reset removal flag if new photo is taken
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error taking photo: $e'))
      );
    }
  }
  // ----------------------------

  @override
  Widget build(BuildContext context) {
    // Responsive values
    final double horizontalPadding = Responsive.value<double>(context, mobile: 16.0, tablet: 24.0);
    final double verticalPadding = Responsive.value<double>(context, mobile: 16.0, tablet: 20.0); // Adjusted vertical padding
    final double spacing = Responsive.value<double>(context, mobile: 16.0, tablet: 20.0);
    final double titleFontSize = Responsive.value<double>(context, mobile: 18.0, tablet: 20.0);

    // Get existing image URLs for the attachment preview list only
    final List<dynamic> existingImageUrlsForPreview = [
      ...?widget.complaint.imageUrls, // Existing URLs (Strings)
    ];
    // Combine existing URLs and newly selected PlatformFiles for attachment preview
    final List<dynamic> allAttachmentsForPreview = [
        ...existingImageUrlsForPreview,
        ..._newlySelectedImages // Newly selected (PlatformFiles)
    ];

    // Determine the main image URL for the top display (prioritize newly taken photo)
     final String? existingMainImageUrl = widget.complaint.imageUrls?.isNotEmpty ?? false
        ? widget.complaint.imageUrls!.first
        : null;

    // Determine if we should *show* the main image (considering removal flag)
    final bool showMainImage = !_mainImageMarkedForRemoval;
    final String? effectiveMainImageUrl = showMainImage ? existingMainImageUrl : null;

    return Form(
      key: formKey,
      // Use ListView for inherent scrollability when content overflows
      child: ListView(
        shrinkWrap: true, // Important for use inside modal bottom sheet
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + verticalPadding), // Adjust padding for keyboard
        children: [
          // --- Title Row with Close Button ---
          Padding(
            padding: EdgeInsets.only(left: horizontalPadding, right: horizontalPadding / 2, top: verticalPadding / 2), // Adjust padding
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${widget.complaint.issueType} Complaint',
                    style: TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis, // Prevent title overflow
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          
          SizedBox(height: spacing * 0.5), // Add some space

          // --- Main Image Display with Camera Icon ---
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: spacing * 0.5),
            child: Stack( // Use Stack to overlay the camera button
              alignment: Alignment.bottomRight, // Align button to bottom right
              children: [
                ClipRRect( // Rounded corners for the image/placeholder container
                  borderRadius: BorderRadius.circular(12.0),
                  child: Container(
                    height: 200, // Adjust height as needed
                    width: double.infinity,
                    color: Colors.grey[200], // Background for placeholder
                    child: _buildMainImagePreview(effectiveMainImageUrl), // Use helper for preview
                  ),
                ),
                // Camera Icon Button
                Padding(
                  padding: const EdgeInsets.all(8.0), // Padding around the button
                  child: Material( // Material for InkWell effect
                    color: Theme.of(context).primaryColor, // Button background color
                    shape: const CircleBorder(), // Circular shape
                    elevation: 2.0, // Add some shadow
                    child: InkWell(
                      onTap: _isUploading ? null : _takePhoto, // Call takePhoto
                      customBorder: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(10.0), // Padding inside the circle
                        child: Icon(
                          Icons.camera_alt,
                          color: Colors.white, // Icon color
                          size: 24.0, // Icon size
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- Form Content ---
          Padding(
             padding: EdgeInsets.symmetric(horizontal: horizontalPadding), // Add padding around form elements
             child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: spacing), // Space before first field

                // --- Removed Non-editable fields ---
                // _buildInfoRow('Ticket ID:', widget.complaint.ticketId),
                // _buildInfoRow('Suburb:', widget.complaint.suburb),
                // _buildInfoRow('Directorate:', widget.complaint.directorate),
                // SizedBox(height: spacing),

                // Editable fields
                DropdownButtonFormField<String>(
                  value: status,
                  items: const [
                    DropdownMenuItem(value: 'In Progress', child: Text('In Progress')),
                    DropdownMenuItem(value: 'Resolved', child: Text('Resolved')),
                  ],
                  onChanged: (value) => setState(() => status = value!),
                  decoration: InputDecoration( // Add border for better look
                    labelText: 'Status',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  ),
                ),
                SizedBox(height: spacing),
                TextFormField(
                  controller: descriptionController,
                  decoration: InputDecoration( // Add border and hintText
                     labelText: 'Description',
                     hintText: 'Enter updated description (optional)', // Add hint text
                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                     alignLabelWithHint: true, // Better alignment for multiline
                  ),
                  maxLines: 4, // Increase max lines slightly
                  // Description is now optional, removing validator
                  // validator: (value) =>
                  //     value!.isEmpty ? 'Please enter a description' : null,
                ),
                SizedBox(height: spacing * 1.5), // More space before attachments

                // --- Image Attachment Section ---
                const Text(
                  'Attachments', // Changed title
                   style: TextStyle(fontWeight: FontWeight.bold)
                 ),
                SizedBox(height: spacing * 0.8),
                // --- Removed Gallery/Camera Button Row ---
                /*
                Row(
                  children: [
                    Expanded( // Use Expanded for flexible button widths
                      child: ElevatedButton.icon(
                        onPressed: _isUploading ? null : _pickImages,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Gallery'),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                      ),
                    ),
                    SizedBox(width: spacing),
                    Expanded( // Use Expanded for flexible button widths
                      child: ElevatedButton.icon(
                        onPressed: _isUploading ? null : _takePhoto,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Camera'),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                      ),
                    ),
                  ],
                ),
                */
                SizedBox(height: spacing * 0.8),
                // Horizontal list for image previews (existing URLs + new PlatformFiles) - Make clickable
                GestureDetector(
                  onTap: _isUploading ? null : _pickImages, // Trigger file picker
                  child: Builder(
                    builder: (context) {
                       if (allAttachmentsForPreview.isNotEmpty)
                        return SizedBox(
                          height: 110,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: allAttachmentsForPreview.length,
                            itemBuilder: (context, index) {
                              final attachmentItem = allAttachmentsForPreview[index];
                              bool isExistingUrl = attachmentItem is String;
                              PlatformFile? newPlatformFile = isExistingUrl ? null : attachmentItem as PlatformFile;

                              // Use the updated preview tile helper
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: _buildAttachmentPreviewTile( // Renamed helper
                                  attachmentItem: attachmentItem,
                                  isExistingUrl: isExistingUrl,
                                  newPlatformFile: newPlatformFile,
                                  onRemove: () {
                                    if (!isExistingUrl && newPlatformFile != null) {
                                      setState(() {
                                        _newlySelectedImages.removeWhere((file) => file.path == newPlatformFile.path);
                                      });
                                    }
                                    // Note: Cannot remove existing URLs from here
                                  },
                                ),
                              );
                            },
                          ),
                        );
                      else
                        return Container( // Placeholder for file picker
                            height: 110,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(color: Colors.grey[300]!)
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.attach_file, color: Colors.grey[600], size: 30), // Changed icon
                                  SizedBox(height: 4),
                                  Text(
                                    'Tap to add Attachments (PDF, JPG, PNG)', // Updated placeholder text
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey[600])
                                   ),
                                ],
                              ),
                            ),
                          );
                    }
                  )
                ),
                SizedBox(height: spacing * 2),

                // --- Action Buttons ---
                // Center the button
                Center(
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _updateComplaint,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                          horizontal: Responsive.value<double>(context, mobile: 50, tablet: 70),
                          vertical: Responsive.value<double>(context, mobile: 14, tablet: 16)),
                      minimumSize: Size(Responsive.value<double>(context, mobile: 120, tablet: 150), 48),
                       backgroundColor: Theme.of(context).primaryColor, // Use theme color
                       foregroundColor: Colors.white, // White text
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)), // Rounded button
                    ),
                    child: _isUploading
                        ? const SizedBox(
                            width: 24, height: 24, // Consistent size
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Update', style: TextStyle(fontSize: 16)), // Slightly larger text
                  ),
                ),
                 SizedBox(height: spacing), // Add space at the bottom
              ],
             ),
          ),
        ],
      ),
    );
  }

  // Helper widget for the MAIN image preview
  Widget _buildMainImagePreview(String? existingImageUrl) {
    // Determine if there's any image to display (newly taken or existing)
    bool hasNewImage = _mainImageToUpload != null;
    bool hasExistingImage = existingImageUrl != null;
    bool showImage = hasNewImage || hasExistingImage;

    // If no image to show (either none initially, or marked for removal), show placeholder
    if (!showImage) {
      return const Center(child: Icon(Icons.image_outlined, size: 60, color: Colors.grey));
    }

    // Build the actual image widget (either from new file or existing URL)
    Widget imageWidget;
    if (hasNewImage) {
      if (kIsWeb) {
        // For web, read bytes and display using Image.memory
        imageWidget = FutureBuilder<Uint8List>(
          future: _mainImageToUpload!.readAsBytes(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
              return Image.memory(snapshot.data!, fit: BoxFit.cover);
            }
            return const Center(child: CircularProgressIndicator()); // Loading placeholder
          },
        );
      } else {
        // For mobile, display using Image.file
        imageWidget = Image.file(File(_mainImageToUpload!.path), fit: BoxFit.cover);
      }
    } else { // Must be existingImageUrl
      print('[_buildMainImagePreview ComplaintID: ${widget.complaint.id}] Trying to load existing URL: $existingImageUrl');
      imageWidget = Image.network(
        existingImageUrl!, // We already checked it's not null
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : const Center(child: CircularProgressIndicator()),
        errorBuilder: (context, error, stackTrace) {
          print('[_buildMainImagePreview ComplaintID: ${widget.complaint.id}] ERROR loading existing image $existingImageUrl: $error');
          print(stackTrace);
          return const Center(child: Icon(Icons.broken_image_outlined, size: 50, color: Colors.grey));
        },
      );
    }

    // Wrap the image widget in a Stack to add the delete button
    return Stack(
      fit: StackFit.expand,
      children: [
        imageWidget, // The actual image (or its loading/error state)
        // Delete button overlay (only if an image is actually shown)
        Positioned(
          top: 4,
          right: 4,
          child: InkWell(
            onTap: _isUploading ? null : () {
              setState(() {
                if (_mainImageToUpload != null) {
                  _mainImageToUpload = null; // Clear newly taken photo
                } else if (existingImageUrl != null) {
                   _mainImageMarkedForRemoval = true; // Mark existing photo for removal
                }
              });
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(4.0),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  // Helper widget for ATTACHMENT preview tiles (handles URL strings and PlatformFiles)
  Widget _buildAttachmentPreviewTile({
    required dynamic attachmentItem,
    required bool isExistingUrl,
    required PlatformFile? newPlatformFile,
    required VoidCallback onRemove,
  }) {
    Widget contentWidget;
    bool isImage = false;

    if (isExistingUrl) {
      // Assume existing URLs are images
      isImage = true;
      final String url = attachmentItem as String;
      print('[_buildAttachmentPreviewTile ComplaintID: ${widget.complaint.id}] Trying to load existing attachment URL: $url');
      contentWidget = Image.network(
        url,
        height: 100, width: 100, fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) => progress == null ? child : Container(width: 100, height: 100, color: Colors.grey[300], child: const Center(child: CircularProgressIndicator())),
        errorBuilder: (ctx, err, st) {
           print('[_buildAttachmentPreviewTile ComplaintID: ${widget.complaint.id}] ERROR loading attachment image $url: $err');
           print(st);
           return Container(width: 100, height: 100, color: Colors.grey[300], child: const Center(child: Icon(Icons.error_outline)));
        },
      );
    } else if (newPlatformFile != null) {
      // Check extension for PlatformFile
      String extension = newPlatformFile.extension?.toLowerCase() ?? '';
      if (['jpg', 'jpeg', 'png'].contains(extension)) {
         isImage = true;
         // Display image preview for PlatformFile
         if (kIsWeb) {
            contentWidget = Image.memory(newPlatformFile.bytes!, height: 100, width: 100, fit: BoxFit.cover);
         } else {
            contentWidget = Image.file(File(newPlatformFile.path!), height: 100, width: 100, fit: BoxFit.cover);
         }
      } else if (extension == 'pdf') {
         // Show PDF icon
         isImage = false;
         contentWidget = Container(
            width: 100, height: 100,
            color: Colors.grey[200],
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                    Icon(Icons.picture_as_pdf, size: 40, color: Colors.red[700]),
                    SizedBox(height: 4),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Text(newPlatformFile.name, style: TextStyle(fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                    ),
                ]
            ),
         );
      } else {
         // Generic file icon for others
         isImage = false;
         contentWidget = Container(width: 100, height: 100, color: Colors.grey[300], child: const Center(child: Icon(Icons.insert_drive_file)));
      }
    } else {
      // Fallback shouldn't usually happen
      contentWidget = Container(width: 100, height: 100, color: Colors.grey[300]);
    }

    return Stack(
      alignment: Alignment.topRight,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: contentWidget,
        ),
        // Show close button only for *newly* selected files/images
        if (!isExistingUrl)
          Positioned(
            top: 2,
            right: 2,
            child: InkWell(
              onTap: _isUploading ? null : onRemove,
              child: Container(
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                padding: const EdgeInsets.all(2.0),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
      ],
    );
  }

  // --- Update Complaint Method (Preparation Step) ---
  Future<void> _updateComplaint() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final bool isMounted = mounted;

    setState(() { _isUploading = true; });

    // --- File Collection (Separated) ---
    // Main image from camera
    final XFile? mainImageFile = _mainImageToUpload;
    // Attachments from file picker
    final List<PlatformFile> attachmentFiles = List.from(_newlySelectedImages); // Create a copy

    // Clear the temporary state holders (BEFORE async gap)
    final tempMainImageToUpload = _mainImageToUpload;
    final tempMainImageMarkedForRemoval = _mainImageMarkedForRemoval;
    _mainImageToUpload = null;
    _newlySelectedImages = [];
    _mainImageMarkedForRemoval = false; // Reset flag in UI state immediately


    // --- Actual Upload Logic ---
    final supabase = Supabase.instance.client;
    String? newMainImageUrl; // To store the URL of the uploaded main image
    List<Map<String, dynamic>> newAttachmentMetadata = []; // Store metadata for attachments bucket uploads

    // Keep track of uploads for potential rollback
    List<String> uploadedComplaintImagePaths = [];
    List<String> uploadedAttachmentPaths = [];

    try {
      // --- 1. Upload Main Complaint Image (if changed) ---
      if (tempMainImageToUpload != null) { // Use the temp variable captured before clearing state
        print('Preparing main image for upload: ${tempMainImageToUpload.path}');
        final originalFileName = tempMainImageToUpload.name;
        print('Original main image filename from picker: $originalFileName');

        final fileBytes = await tempMainImageToUpload.readAsBytes();
        final fileSize = fileBytes.length;

        // Determine MIME type (still useful)
        String mimeType = lookupMimeType(originalFileName, headerBytes: fileBytes.sublist(0, 1024)) ?? 'image/jpeg';

        // Generate simplified, unique path - IGNORING ORIGINAL NAME
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final String fileExtension = '.jpg'; // Force jpg for simplicity
        final uniqueFileName = 'main_${timestamp}$fileExtension'; // Simple name: main_123456789.jpg
        final uniqueComplaintImagePath = '${widget.complaint.id}/$uniqueFileName'; // Path: complaintId/main_123456789.jpg

        print('Uploading main image to complaintimages: $uniqueFileName ($mimeType, $fileSize bytes) to $uniqueComplaintImagePath');

        // Upload to complaintimages bucket
        await supabase.storage
            .from('complaintimages') 
            .uploadBinary(
              uniqueComplaintImagePath, // Use the simplified path
              fileBytes,
              fileOptions: FileOptions(contentType: mimeType, upsert: false),
            );
        uploadedComplaintImagePaths.add(uniqueComplaintImagePath); 

        // Sanitize path before getting URL (should be redundant now but safe)
        final sanitizedPathForUrl = uniqueComplaintImagePath.replaceAll(RegExp(r'^/+'), '').replaceAll(RegExp(r'/+$'), '');

        // Get public URL for the main image
        newMainImageUrl = supabase.storage
            .from('complaintimages') 
            .getPublicUrl(sanitizedPathForUrl); // Use the simplified path
        print('Got Public URL for main image: $newMainImageUrl (from path: $sanitizedPathForUrl)');
      } else {
         print('No new main image selected.');
      }

      // --- 2. Handle Deletion of Existing Main Image (if marked) ---
      bool removedExistingMainImage = false;
      if (tempMainImageToUpload == null && tempMainImageMarkedForRemoval && widget.complaint.hasImages) {
          // If no *new* image was provided AND the existing one was marked for removal
          final existingImageUrl = widget.complaint.imageUrls!.first;
          // Extract the path from the URL to delete from storage
          try {
              final uri = Uri.parse(existingImageUrl);
              // Assuming path structure like /storage/v1/object/public/bucketname/complaintId/filename.jpg
              // We need 'complaintId/filename.jpg'
              final pathSegments = uri.pathSegments;
              if (pathSegments.length >= 5) { // Adjust index based on actual URL structure
                  final bucketName = pathSegments[3]; // e.g., 'complaintimages'
                  final imagePath = pathSegments.sublist(4).join('/'); // e.g., 'complaintId/filename.jpg'

                  if (bucketName == 'complaintimages' && imagePath.isNotEmpty) {
                       print('Attempting to remove existing main image from storage: $imagePath');
                       await supabase.storage.from(bucketName).remove([imagePath]);
                       print('Successfully removed existing main image from storage.');
                       removedExistingMainImage = true; // Flag that we successfully deleted it
                  } else {
                     print('Could not extract valid path from URL for deletion: $existingImageUrl');
                  }
              } else {
                   print('Could not parse storage path from URL: $existingImageUrl');
              }
          } catch (e) {
             print('Error attempting to remove existing main image from storage: $e');
             // Decide if you want to proceed or show an error. Maybe log and continue.
          }
      }

      // --- 3. Upload Attachments (if any) ---
      if (attachmentFiles.isNotEmpty) {
        print('Starting upload process for ${attachmentFiles.length} attachments...');
        for (var file in attachmentFiles) {
          String fileName;
          Uint8List fileBytes;
          String? mimeType;
          int fileSize;

          // Generate a unique file name using complaint ID and timestamp for attachments bucket
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final originalFileName = file.name;
          final sanitizedOriginalFileName = originalFileName.replaceAll(RegExp(r'[^\\w\\.-]+'), '_');
          // Path within attachments bucket
          final uniqueAttachmentPath = '${widget.complaint.id}/attachment_${timestamp}_$sanitizedOriginalFileName';

          fileName = sanitizedOriginalFileName;
          if (kIsWeb) {
            fileBytes = file.bytes!;
            fileSize = file.bytes!.length;
          } else {
            final fileOnDevice = File(file.path!);
            fileBytes = await fileOnDevice.readAsBytes();
            fileSize = await fileOnDevice.length();
          }
          mimeType = lookupMimeType(fileName, headerBytes: fileBytes.sublist(0, kIsWeb ? (fileBytes.length > 1024 ? 1024 : fileBytes.length) : 1024)) ?? 'application/octet-stream';

          print('Uploading attachment to attachments: $fileName ($mimeType, $fileSize bytes) to $uniqueAttachmentPath');

          // Upload to attachments bucket
          await supabase.storage
              .from('attachments') // <--- Target attachments bucket
              .uploadBinary(
                uniqueAttachmentPath,
                fileBytes,
                fileOptions: FileOptions(contentType: mimeType, upsert: false),
              );
          uploadedAttachmentPaths.add(uniqueAttachmentPath); // Track for rollback

          // Sanitize path before getting URL
          final sanitizedAttachmentPathForUrl = uniqueAttachmentPath.replaceAll(RegExp(r'^/+'), '').replaceAll(RegExp(r'/+$'), '');

          // Get Public URL for the attachment
          final attachmentPublicUrl = supabase.storage
              .from('attachments') // <--- Get URL from attachments bucket
              .getPublicUrl(sanitizedAttachmentPathForUrl); // <-- Use sanitized path
          print('Got Public URL for attachment: $attachmentPublicUrl (from path: $sanitizedAttachmentPathForUrl)');

          // Prepare metadata for attachmentsData field
          newAttachmentMetadata.add({
            'storage_path': uniqueAttachmentPath, // Path within attachments bucket
            'file_name': fileName,
            'mime_type': mimeType,
            'size': fileSize,
            'uploaded_at': DateTime.now().toIso8601String(),
            'public_url': attachmentPublicUrl, // Store public URL in metadata
          });
          print('Prepared metadata for attachment $fileName');
        }
      } else {
         print('No new attachments selected for upload.');
      }

      // --- Prepare final data for update ---

      // Final Image URLs
      List<String>? finalImageUrls;
      if (newMainImageUrl != null) {
          // New image was uploaded, use its URL
          finalImageUrls = [newMainImageUrl!];
      } else if (removedExistingMainImage) {
           // Existing image was successfully removed, set to empty list or null
           finalImageUrls = []; // Or null depending on your model/DB schema
      } else if (tempMainImageMarkedForRemoval) {
          // Marked for removal, but deletion failed or wasn't attempted, KEEP existing URL?
          // Or maybe still remove it from the DB record even if storage failed? Let's remove it.
          finalImageUrls = []; // Or null
           print('Warning: Main image marked for removal, but storage deletion might have failed. Removing URL from record anyway.');
      } else {
          // No new image, not marked for removal, keep existing
          finalImageUrls = widget.complaint.imageUrls;
      }


      // Final Attachments Metadata
      List<Map<String, dynamic>> existingAttachments = List<Map<String, dynamic>>.from(
         widget.complaint.attachmentsData?.map((e) => Map<String, dynamic>.from(e)) ?? []
      );
      List<Map<String, dynamic>> finalAttachmentsData = [
          ...existingAttachments,
          ...newAttachmentMetadata // Add only new attachment metadata here
      ];

      // --- Update Complaint Record ---
      final updatedComplaint = widget.complaint.copyWith(
        description: descriptionController.text.isNotEmpty ? descriptionController.text : widget.complaint.description,
        status: status,
        lastUpdated: DateTime.now(),
        attachmentsData: finalAttachmentsData, // Update attachments metadata
        imageUrls: finalImageUrls, // Update main image URL(s) based on upload/removal
      );

      print('[_updateComplaint] Updating complaint details (imageUrls and attachmentsData) in provider...');
      await widget.complaintProvider.updateComplaint(updatedComplaint);
      print('[_updateComplaint] Complaint update request sent.');

      if (!isMounted) return;
      navigator.pop(); // Close the dialog
      messenger.showSnackBar(
       SnackBar(content: Text('Complaint updated successfully${(tempMainImageToUpload != null || attachmentFiles.isNotEmpty) ? " with uploads" : ""}!'))
      );

    } catch (e, stackTrace) {
       print('[_updateComplaint] Error during update/upload: $e');
       print('[_updateComplaint] StackTrace: $stackTrace');
       // Attempt to delete newly uploaded files if DB update fails
       if (uploadedComplaintImagePaths.isNotEmpty) {
         try {
           print('Attempting to rollback complaintimages uploads...');
           await supabase.storage.from('complaintimages').remove(uploadedComplaintImagePaths);
           print('Rollback successful for complaintimages paths: $uploadedComplaintImagePaths');
         } catch (rollbackError) {
           print('Error during complaintimages storage rollback: $rollbackError');
         }
       }
       if (uploadedAttachmentPaths.isNotEmpty) {
         try {
           print('Attempting to rollback attachments uploads...');
           await supabase.storage.from('attachments').remove(uploadedAttachmentPaths);
           print('Rollback successful for attachments paths: $uploadedAttachmentPaths');
         } catch (rollbackError) {
           print('Error during attachments storage rollback: $rollbackError');
         }
       }
       if (!isMounted) return;
       messenger.showSnackBar(
         SnackBar(content: Text('Error updating complaint or uploading files: $e'))
       );
    } finally {
       if (isMounted) {
          // Reset state even on error, or maybe only on success?
          // For now, reset regardless
          setState(() {
             _isUploading = false;
             // _mainImageToUpload = null; // Already cleared at start
             // _newlySelectedImages.clear(); // Already cleared at start
           });
       }
    }
  }
  // ------------------------
}