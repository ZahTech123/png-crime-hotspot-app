import 'package:flutter/material.dart';
import 'package:ncdc_ccms_app/models.dart';
import 'package:ncdc_ccms_app/image_service.dart';
import 'package:ncdc_ccms_app/complaints/complaint_card.dart';

class ComplaintsList extends StatelessWidget {
  final List<CityComplaint> complaints;
  final Function(CityComplaint) onEdit;
  final Function(String) onDelete;
  final ImageService imageService;
  final PageController? pageController;
  final ScrollController? scrollController;
  final ValueChanged<int>? onPageChanged;
  final Function(CityComplaint)? onShowDetails;

  const ComplaintsList({
    super.key,
    required this.complaints,
    required this.onEdit,
    required this.onDelete,
    required this.imageService,
    this.pageController,
    this.scrollController,
    this.onPageChanged,
    this.onShowDetails,
  });

  @override
  Widget build(BuildContext context) {
    if (complaints.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sentiment_dissatisfied, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No complaints to display.', style: TextStyle(fontSize: 16)),
            Text('Pull down to refresh or add a new one.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    // Using PageView for horizontal swiping through complaints
    return PageView.builder(
      controller: PageController(viewportFraction: 0.9), // Show parts of next/prev cards
      itemCount: complaints.length,
      itemBuilder: (context, index) {
        final complaint = complaints[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
          child: ComplaintCard(
            complaint: complaint,
          ),
        );
      },
    );
  }
}