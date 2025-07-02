import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models.dart';
import '../image_service.dart';

class ComplaintDetailsSheet extends StatefulWidget {
  final Complaint complaint;
  final Function(Complaint) onEdit;
  final Function(String) onDelete;
  final VoidCallback onClose;
  final ImageService imageService;

  const ComplaintDetailsSheet({
    super.key,
    required this.complaint,
    required this.onEdit,
    required this.onDelete,
    required this.onClose,
    required this.imageService,
  });

  @override
  State<ComplaintDetailsSheet> createState() => _ComplaintDetailsSheetState();
}

class _ComplaintDetailsSheetState extends State<ComplaintDetailsSheet> {
  bool _isUpdating = false;
  bool _isUploadingImages = false;

  Future<void> _markAsResolved() async {
    if (widget.complaint.status == 'Resolved') return;

    setState(() => _isUpdating = true);
    
    try {
      final updatedComplaint = widget.complaint.copyWith(
        status: 'Resolved',
        lastUpdated: DateTime.now(),
        resolved: true,
      );
      
      await widget.onEdit(updatedComplaint);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complaint marked as resolved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _addImages() async {
    try {
      final action = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Add Images'),
          content: const Text('Select image source'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 1),
              child: const Text('Camera'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 2),
              child: const Text('Gallery'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 0),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      List<XFile> selectedImages = [];
      if (action == 1) {
        final XFile? photo = await widget.imageService.takePhoto();
        if (photo != null) selectedImages.add(photo);
      } else if (action == 2) {
        selectedImages = await widget.imageService.pickImages();
      }

      if (selectedImages.isNotEmpty) {
        setState(() => _isUploadingImages = true);
        final newImageUrls = await widget.imageService.uploadImages(
          selectedImages, 
          widget.complaint.id
        );
        
        final updatedComplaint = widget.complaint.copyWith(
          imageUrls: [...?widget.complaint.imageUrls, ...newImageUrls],
          lastUpdated: DateTime.now(),
        );
        
        await widget.onEdit(updatedComplaint);
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Images uploaded successfully')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading images: $e')),
      );
    } finally {
      setState(() => _isUploadingImages = false);
    }
  }

  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 3.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height; // Get screen height

    // Wrap the SingleChildScrollView with a SizedBox to constrain its height and width
    return SizedBox(
      height: screenHeight * 0.9, // Use 90% of screen height for the sheet
      width: double.infinity, // Take full available width
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderRow(context),
            const Divider(),
            _buildDetailRows(context),
            _buildDescriptionSection(),
            _buildImageSection(),
            if (widget.complaint.previousHandlers?.isNotEmpty == true)
              _buildHandlingHistorySection(),
            const SizedBox(height: 24),
            _buildActionButtons(context),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          widget.complaint.ticketId,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onClose,
        ),
      ],
    );
  }

  Widget _buildDetailRows(BuildContext context) {
    return Column(
      children: [
        _buildStatusRow(context),
        _buildDetailRow(context, 'Priority', widget.complaint.priority,
            icon: widget.complaint.getPriorityIcon(), 
            iconColor: widget.complaint.getPriorityColor()),
        _buildDetailRow(context, 'Issue Type', widget.complaint.issueType),
        _buildDetailRow(context, 'Directorate', widget.complaint.directorate),
        _buildDetailRow(context, 'Team', widget.complaint.team),
        _buildDetailRow(context, 'Submitted By', widget.complaint.name),
        _buildDetailRow(
            context, 'Date Submitted', widget.complaint.formattedDateSubmitted),
        _buildDetailRow(
            context, 'Location',
            '${widget.complaint.suburb}, ${widget.complaint.electorate}'),
        _buildDetailRow(
            context, 'Current Handler', widget.complaint.currentHandler),
      ],
    );
  }

  Widget _buildStatusRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              'Status:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.complaint.status,
                  style: TextStyle(color: widget.complaint.statusColor),
                ),
                if (widget.complaint.status != 'Resolved') ...[
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _isUpdating ? null : _markAsResolved,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: _isUpdating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Mark as Resolved'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            const Text(
              'Attachments:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add_a_photo),
              onPressed: _isUploadingImages ? null : _addImages,
              tooltip: 'Add images',
            ),
          ],
        ),
        if (_isUploadingImages)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
        if (widget.complaint.hasImages)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.complaint.imageUrls?.length ?? 0,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _showFullImage(widget.complaint.imageUrls![index]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        widget.complaint.imageUrls![index],
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 100,
                            height: 100,
                            color: Colors.grey[200],
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 100,
                            height: 100,
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        if (!widget.complaint.hasImages)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No images attached'),
          ),
      ],
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    IconData? icon,
    Color? iconColor,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
          ),
          const SizedBox(width: 8),
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(icon, size: 16, color: iconColor),
            ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Description:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(widget.complaint.description),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildHandlingHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Handling History:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        ...?widget.complaint.previousHandlers
            ?.where((handler) => handler.isNotEmpty)
            .map((handler) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('- $handler'),
                )),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton(
          onPressed: () => widget.onEdit(widget.complaint),
          child: const Text('Edit'),
        ),
        ElevatedButton(
          onPressed: () => widget.onDelete(widget.complaint.id),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}