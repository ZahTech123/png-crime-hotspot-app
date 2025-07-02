import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models.dart';
import '../image_service.dart'; // Assuming you might need this for advanced image handling

class ComplaintCard extends StatefulWidget {
  final Complaint complaint;
  final Function(Complaint)? onEdit;
  final Function(String)? onDelete;
  final Function(Complaint)? onTap;
  final ImageService imageService;

  const ComplaintCard({
    super.key,
    required this.complaint,
    required this.imageService,
    this.onEdit,
    this.onDelete,
    this.onTap,
  });

  @override
  State<ComplaintCard> createState() => _ComplaintCardState();
}

class _ComplaintCardState extends State<ComplaintCard> {
  int _currentImageIndex = 0;
  bool _isConfirmed = false; // Local state to track confirmation

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      clipBehavior: Clip.antiAlias,
      elevation: 3.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Carousel Section
          _buildImageCarousel(),
          
          // Content Section
          _buildContentSection(context),

          // Divider
          const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
          
          // Action Buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildImageCarousel() {
    final hasImages = widget.complaint.imageUrls != null && widget.complaint.imageUrls!.isNotEmpty;

    if (!hasImages) {
      // Return a placeholder or an empty container if there are no images
      return Container(
        height: 180,
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.image_not_supported, color: Colors.grey, size: 50),
        ),
      );
    }

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            itemCount: widget.complaint.imageUrls!.length,
            onPageChanged: (index) {
              setState(() {
                _currentImageIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final imageUrl = widget.complaint.imageUrls![index];
              return Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.broken_image, color: Colors.grey, size: 50),
                    ),
                  );
                },
              );
            },
          ),
        ),
        // Page Indicator
        if (widget.complaint.imageUrls!.length > 1)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.complaint.imageUrls!.length, (index) {
                return Container(
                  width: 8.0,
                  height: 8.0,
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == index
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildContentSection(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final timeAgo = timeago.format(widget.complaint.submissionTime);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            widget.complaint.issueType,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),

          // Suburb, Author and Time
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${widget.complaint.suburb}, ${widget.complaint.electorate}',
                  style: textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'By ${widget.complaint.author}',
                    style: textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                  ),
                  Text(
                    timeAgo,
                    style: textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 12),
          
          // Description
          Text(
            widget.complaint.description,
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          
          // Confirms and Comments
          Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
              const SizedBox(width: 4),
              Text('${widget.complaint.confirms} Confirms'),
              const Spacer(), // Pushes the next widget to the end
              const Icon(Icons.comment_outlined, color: Colors.grey, size: 16),
              const SizedBox(width: 4),
              Text('${widget.complaint.commentsCount} Comments'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          TextButton.icon(
            onPressed: () {
              setState(() {
                _isConfirmed = !_isConfirmed;
                // Here you would also call a service to update the backend
              });
            },
            icon: Icon(
              _isConfirmed ? Icons.check_circle : Icons.check_circle_outline,
              color: _isConfirmed ? Colors.green : Colors.grey[700],
            ),
            label: Text(
              'Confirmed',
              style: TextStyle(color: _isConfirmed ? Colors.green : Colors.grey[700]),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              // TODO: Implement comment functionality
            },
            icon: Icon(Icons.comment_outlined, color: Colors.grey[700]),
            label: Text('Comment', style: TextStyle(color: Colors.grey[700])),
          ),
          TextButton.icon(
            onPressed: () {
              // TODO: Implement share functionality
            },
            icon: Icon(Icons.share_outlined, color: Colors.grey[700]),
            label: Text('Share', style: TextStyle(color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }
}