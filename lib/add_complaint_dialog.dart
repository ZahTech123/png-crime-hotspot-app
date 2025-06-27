import 'dart:io'; // Needed for File type in previews
import 'dart:typed_data'; // Needed for Uint8List for web preview
import 'package:flutter/foundation.dart' show kIsWeb; // Import kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Import XFile
import 'package:uuid/uuid.dart'; // Revert back to standard import
import '../models.dart'; // Adjusted import path
import '../complaint_provider.dart'; // Adjusted import path
import '../image_service.dart'; // Adjusted import path
import '../utils/responsive.dart'; // Import the Responsive helper

class AddComplaintDialog extends StatefulWidget {
  final ComplaintProvider complaintProvider;
  final ImageService imageService;
  
  const AddComplaintDialog({
    super.key, 
    required this.complaintProvider, 
    required this.imageService, 
  });

  @override
  State<AddComplaintDialog> createState() => _AddComplaintDialogState();
}

class _AddComplaintDialogState extends State<AddComplaintDialog> {
  final formKey = GlobalKey<FormState>();
  final suburbController = TextEditingController();
  final descriptionController = TextEditingController();
  
  String priority = 'Medium';
  String directorate = 'Sustainability & Lifestyle';
  String? issueType;
  List<XFile> _selectedImages = []; // State variable for selected images
  bool _isUploading = false; // State for loading indicator during upload/save

  @override
  void initState() {
    super.initState();
    final initialIssueTypes = _getIssueTypesForDirectorate(directorate);
    if (initialIssueTypes.isNotEmpty) {
      issueType = initialIssueTypes.first;
    }
  }

  List<String> _getIssueTypesForDirectorate(String directorate) {
    switch (directorate) {
      case 'Sustainability & Lifestyle':
        return [
          'Urban Safety',
          'Waste Management',
          'Markets',
          'Parks & Gardens',
          'Eda City Bus'
        ];
      case 'Compliance':
        return [
          'Liquor License',
          'Building',
          'Development Control & Physical Planning',
          'Enforcement'
        ];
      case 'City Planning & Infrastructure':
        return [
          'Streetlights & Traffic Management',
          'Road Furniture & Road Signs',
          'Potholes & Drainage',
          'Strategic Planning'
        ];
      default:
        return [];
    }
  }

  // --- Image Picking Methods ---
  Future<void> _pickImages() async {
    try {
      final List<XFile> picked = await widget.imageService.pickImages();
      if (picked.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(picked);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking images: $e'))
      );
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await widget.imageService.takePhoto();
      if (photo != null) {
        setState(() {
          _selectedImages.add(photo);
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
    final issueTypes = _getIssueTypesForDirectorate(directorate);
    final screenHeight = Responsive.screenHeight(context); // Use Responsive helper
    final screenWidth = Responsive.screenWidth(context);   // Use Responsive helper

    // Responsive values
    final double dialogHeightPercent = Responsive.value<double>(context, mobile: 0.8, tablet: 0.7);
    final double dialogWidthPercent = Responsive.value<double>(context, mobile: 0.9, tablet: 0.7);
    final double horizontalPadding = Responsive.value<double>(context, mobile: 16.0, tablet: 24.0);
    final double verticalPadding = Responsive.value<double>(context, mobile: 20.0, tablet: 24.0);
    final double spacing = Responsive.value<double>(context, mobile: 16.0, tablet: 20.0);
    final double titleFontSize = Responsive.value<double>(context, mobile: 18.0, tablet: 20.0);
    final double maxDialogWidth = 600.0; // Example max width

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        // Use responsive padding
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
        child: Center( // Center the constrained content
          child: ConstrainedBox( // Add max width constraint
            constraints: BoxConstraints(maxWidth: maxDialogWidth),
            child: SizedBox( // Wrap Form with SizedBox
              height: screenHeight * dialogHeightPercent, // Use responsive height percentage
              width: screenWidth * dialogWidthPercent,   // Use responsive width percentage
              child: Form( // Keep Form for validation
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       // --- Title ---
                       Text( // Use responsive font size
                         'Add New Complaint',
                         style: TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.bold)
                       ),
                       SizedBox(height: spacing), // Use responsive spacing
                       // --- Form Fields ---
                       // (Directorate Dropdown)
                       DropdownButtonFormField<String>(
                         value: directorate,
                         items: const [
                           DropdownMenuItem(
                             value: 'Sustainability & Lifestyle',
                             child: Text('Sustainability & Lifestyle')),
                           DropdownMenuItem(
                             value: 'Compliance',
                             child: Text('Compliance')),
                           DropdownMenuItem(
                             value: 'City Planning & Infrastructure',
                             child: Text('City Planning & Infrastructure')),
                         ],
                         onChanged: (value) {
                           if (value == null || value == directorate) return; // No change
                           setState(() {
                             directorate = value; // Update directorate
                             // --- MOVE issueType update logic here ---
                             final newIssueTypes = _getIssueTypesForDirectorate(directorate);
                             // Reset issueType only if the new list doesn't contain the old one
                             // or if the new list is empty.
                             if (newIssueTypes.isEmpty || !newIssueTypes.contains(issueType)) {
                                issueType = newIssueTypes.isNotEmpty ? newIssueTypes.first : null;
                             }
                             // --- End moved logic ---
                           });
                         },
                         decoration: const InputDecoration(labelText: 'Directorate'),
                       ),
                       SizedBox(height: spacing), // Use responsive spacing
                       // (Issue Type Dropdown)
                       if (issueTypes.isNotEmpty) 
                         DropdownButtonFormField<String>(
                           value: issueType,
                           isExpanded: true,
                           items: issueTypes
                               .map((type) => DropdownMenuItem(
                                     value: type,
                                     child: Text(type, overflow: TextOverflow.ellipsis),
                                   ))
                               .toList(),
                           onChanged: (value) {
                             setState(() {
                               issueType = value;
                             });
                           },
                           decoration: const InputDecoration(labelText: 'Issue Type'),
                           validator: (value) => value == null ? 'Please select an issue type' : null,
                         )
                       else
                         const Padding(
                           padding: EdgeInsets.symmetric(vertical: 8.0),
                           child: Text('No issue types available for this directorate'),
                         ),
                       SizedBox(height: spacing), // Use responsive spacing
                       // (Suburb TextField)
                       TextFormField(
                         controller: suburbController,
                         decoration: const InputDecoration(labelText: 'Suburb'),
                         validator: (value) => value!.isEmpty ? 'Please enter a suburb' : null,
                       ),
                       SizedBox(height: spacing), // Use responsive spacing
                       // (Priority Dropdown)
                       DropdownButtonFormField<String>(
                         value: priority,
                         items: const [
                           DropdownMenuItem(
                             value: 'High',
                             child: Text('High Priority')),
                           DropdownMenuItem(
                             value: 'Medium',
                             child: Text('Medium Priority')),
                           DropdownMenuItem(
                             value: 'Low',
                             child: Text('Low Priority')),
                         ],
                         onChanged: (value) {
                           setState(() {
                             priority = value!;
                           });
                         },
                         decoration: const InputDecoration(labelText: 'Priority'),
                       ),
                       SizedBox(height: spacing), // Use responsive spacing
                       // (Description TextField)
                       TextFormField(
                         controller: descriptionController,
                         decoration: const InputDecoration(labelText: 'Description'),
                         maxLines: 3,
                         validator: (value) => value!.isEmpty ? 'Please enter a description' : null,
                       ),
                       // --- Image Section ---
                       SizedBox(height: spacing), // Use responsive spacing
                       const Divider(),
                       SizedBox(height: spacing * 0.6), // Smaller spacing
                       const Text('Attach Images', style: TextStyle(fontWeight: FontWeight.bold)),
                       SizedBox(height: spacing * 0.6), // Smaller spacing
                       Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Flexible( // Wrap button with Flexible
                              child: ElevatedButton.icon(
                                onPressed: _pickImages,
                                icon: const Icon(Icons.photo_library, size: 24.0),
                                label: const Text('Gallery'),
                                // Optional: Adjust button padding/style responsively
                              ),
                            ),
                            SizedBox(width: spacing * 0.5), // Responsive space between buttons
                            Flexible( // Wrap button with Flexible
                              child: ElevatedButton.icon(
                                onPressed: _takePhoto,
                                icon: const Icon(Icons.camera_alt, size: 24.0),
                                label: const Text('Camera'),
                                // Optional: Adjust button padding/style responsively
                              ),
                            ),
                          ],
                       ),
                       SizedBox(height: spacing * 0.6), // Smaller spacing
                       if (_selectedImages.isNotEmpty)
                         SizedBox(
                           height: 110, 
                           child: Padding(
                             padding: const EdgeInsets.symmetric(vertical: 8.0),
                             child: ListView.builder(
                               scrollDirection: Axis.horizontal,
                               itemCount: _selectedImages.length,
                               itemBuilder: (context, index) {
                                 final imageFile = _selectedImages[index];
                                 
                                 return Padding(
                                   padding: const EdgeInsets.only(right: 8.0),
                                   child: Stack(
                                     alignment: Alignment.topRight,
                                     children: [
                                       kIsWeb 
                                         ? FutureBuilder<Uint8List>(
                                             future: imageFile.readAsBytes(),
                                             builder: (context, snapshot) {
                                               if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                                                 return ClipRRect(
                                                   borderRadius: BorderRadius.circular(8.0),
                                                   child: Image.memory(
                                                     snapshot.data!,
                                                     height: 100,
                                                     width: 100,
                                                     fit: BoxFit.cover,
                                                     errorBuilder: (ctx, err, st) => Container(width: 100, height: 100, color: Colors.grey[300], child: const Center(child: Icon(Icons.error_outline))),
                                                   ),
                                                 );
                                               } else if (snapshot.hasError) {
                                                  return Container(width: 100, height: 100, color: Colors.grey[300], child: const Center(child: Icon(Icons.error_outline)));
                                               } else {
                                                  return Container(width: 100, height: 100, color: Colors.grey[300], child: const Center(child: CircularProgressIndicator()));
                                               }
                                             },
                                           )
                                         : ClipRRect(
                                             borderRadius: BorderRadius.circular(8.0),
                                             child: Image.file(
                                               File(imageFile.path),
                                               height: 100,
                                               width: 100,
                                               fit: BoxFit.cover,
                                               errorBuilder: (ctx, err, st) => Container(width: 100, height: 100, color: Colors.grey[300], child: const Center(child: Icon(Icons.error_outline))),
                                             ),
                                           ),
                                       InkWell(
                                         onTap: () {
                                           setState(() {
                                             _selectedImages.removeAt(index);
                                           });
                                         },
                                         child: Container(
                                           margin: const EdgeInsets.all(4.0),
                                           decoration: BoxDecoration(
                                             color: Colors.black54,
                                             borderRadius: BorderRadius.circular(10),
                                           ),
                                           padding: const EdgeInsets.all(2.0),
                                           child: const Icon(Icons.close, color: Colors.white, size: 14),
                                         ),
                                       ),
                                     ],
                                   ),
                                 );
                               },
                             ),
                           ),
                         )
                       else 
                         const Padding(
                           padding: EdgeInsets.symmetric(vertical: 10.0),
                           child: Text('No images selected', textAlign: TextAlign.center),
                         ),
                       // --- END Image Section --- 
                       SizedBox(height: spacing * 1.5), // Adjusted spacing like example
                       // --- Action Buttons --- 
                       // Centered button like example (adjust if needed)
                       Center(
                         child: ElevatedButton(
                           onPressed: _isUploading ? null : _saveComplaint,
                           // Style similar to example (adjust padding/shape)
                           style: ElevatedButton.styleFrom(
                             padding: EdgeInsets.symmetric(
                               horizontal: Responsive.value<double>(context, mobile: 40, tablet: 50),
                               vertical: Responsive.value<double>(context, mobile: 12, tablet: 15)
                             ),
                             shape: RoundedRectangleBorder(
                               borderRadius: BorderRadius.circular(30.0),
                             ),
                           ),
                           child: _isUploading 
                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                                  : const Text('Save Complaint'), // Changed text
                         ),
                       ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Save Complaint Method --- 
  Future<void> _saveComplaint() async {
    if (formKey.currentState!.validate() && issueType != null) {
      // Store context-dependent objects BEFORE async gaps
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      final bool isMounted = mounted; // Capture mounted state

      setState(() { _isUploading = true; });
      
      List<String> imageUrls = [];
      String complaintId = const Uuid().v4(); // Generate unique ID

      try {
        // Upload images if any were selected
        if (_selectedImages.isNotEmpty) {
          print('[_saveComplaint] Uploading ${_selectedImages.length} images...'); // Add log
          imageUrls = await widget.imageService.uploadImages(_selectedImages, complaintId);
          print('[_saveComplaint] Image URLs received: $imageUrls'); // Add log
        }

        // Create complaint object with generated ID and image URLs
        final newComplaint = CityComplaint(
          id: complaintId, // Use generated UUID
          ticketId: 'TICKET-${DateTime.now().millisecondsSinceEpoch}', // Consider a better ticket ID generation
          issueType: issueType!,
          suburb: suburbController.text,
          description: descriptionController.text,
          status: 'New',
          priority: priority,
          directorate: directorate,
          dateSubmitted: DateTime.now(),
          electorate: '', // TODO: Get electorate based on suburb?
          currentHandler: '', // TODO: Set initial handler?
          previousHandler: null,
          previousHandlers: [],
          resolved: false,
          latitude: 0.0, // TODO: Get location data?
          longitude: 0.0, // TODO: Get location data?
          name: '', // TODO: Get reporter name?
          team: '', // TODO: Assign team based on directorate/issue?
          submissionTime: DateTime.now(), // TODO: Fix time parsing if needed
          closedTime: null,
          lastUpdated: DateTime.now(),
          emailEscalation: false,
          escalationCount: 0,
          handlerStartDateAndTime: DateTime.now(),
          lastEscalated: null,
          isNew: true, // TODO: Review isNew/isRead logic
          isRead: false,
          imageUrls: imageUrls,
        );
        
        print('[_saveComplaint] Adding complaint to provider...'); // Add log
        // Add complaint to the database via provider
        await widget.complaintProvider.addComplaint(newComplaint);
        print('[_saveComplaint] Complaint added via provider.'); // Add log
        
        // Use captured mounted state and context objects
        if (!isMounted) return;
        
        navigator.pop(); // Close dialog using captured navigator
        messenger.showSnackBar( // Use captured messenger
          const SnackBar(content: Text('Complaint added successfully'))
        );

      } catch (e) {
         print('[_saveComplaint] Error saving complaint: $e'); // Log the error
         // Use captured mounted state and context objects
         if (!isMounted) return;
         messenger.showSnackBar( // Use captured messenger
           SnackBar(content: Text('Error saving complaint: $e'))
         );
      } finally {
        // Use captured mounted state
        if (isMounted) {
           setState(() { _isUploading = false; });
        }
      }
    }
  }
  // ------------------------
}