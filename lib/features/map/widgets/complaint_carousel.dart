import 'package:flutter/material.dart';
import './complaint_info_card.dart';
import '../../../utils/size_config.dart';

class ComplaintCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> complaintsData;
  final Function(int) onPageChanged;
  final Function(String) onShowDetails;
  final Function() onClose;
  final PageController pageController;

  const ComplaintCarousel({
    super.key,
    required this.complaintsData,
    required this.onPageChanged,
    required this.onShowDetails,
    required this.onClose,
    required this.pageController,
  });

  @override
  State<ComplaintCarousel> createState() => ComplaintCarouselState();
}

class ComplaintCarouselState extends State<ComplaintCarousel> {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: Container(
        height: getProportionateScreenHeight(240), // Responsive height
        child: PageView.builder(
          controller: widget.pageController,
          itemCount: widget.complaintsData.length,
          onPageChanged: widget.onPageChanged,
          itemBuilder: (context, index) {
            final complaint = widget.complaintsData[index];
            // Provide default values to avoid null errors
            final title = complaint['issueType'] as String? ?? 'No Title';
            final status = complaint['status'] as String? ?? 'Unknown';
            
            // --- Use the actual image from the database if available ---
            final imageUrls = complaint['imageUrls'] as List<dynamic>?;
            final String imageUrl;
            if (imageUrls != null && imageUrls.isNotEmpty && imageUrls.first is String) {
              imageUrl = imageUrls.first as String;
            } else {
              // Use a placeholder if no image is available
              imageUrl = 'https://www.civicpro.com/media/2529/complaint-management.jpg';
            }
            // -----------------------------------------------------------
            
            final complaintId = complaint['id']?.toString() ?? '';

            return ComplaintInfoCard(
              title: title,
              status: status,
              imageUrl: imageUrl,
              onShowMoreInfo: () => widget.onShowDetails(complaintId),
              onClose: widget.onClose,
            );
          },
        ),
      ),
    );
  }
} 