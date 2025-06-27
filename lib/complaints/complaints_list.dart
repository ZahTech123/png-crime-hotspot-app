import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../image_service.dart';
import 'complaint_card.dart';
import 'complaint_details_sheet.dart';

class ComplaintsList extends StatelessWidget {
  final List<CityComplaint> complaints;
  final Function(CityComplaint) onEdit;
  final Function(String) onDelete;
  final ImageService imageService;

  const ComplaintsList({
    super.key,
    required this.complaints,
    required this.onEdit,
    required this.onDelete,
    required this.imageService,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: complaints.length,
      itemBuilder: (context, index) {
        final complaint = complaints[index];
        return ComplaintCard(
          complaint: complaint,
          onEdit: onEdit,
          onDelete: onDelete,
          onTap: (selectedComplaint) => _showComplaintDetails(
              context, selectedComplaint, onEdit, onDelete, imageService),
          imageService: imageService,
        );
      },
    );
  }

  void _showComplaintDetails(
    BuildContext context, 
    CityComplaint complaint, 
    Function(CityComplaint) onEdit,
    Function(String) onDelete,
    ImageService imageService,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return ComplaintDetailsSheet(
          complaint: complaint,
          onEdit: onEdit,
          onDelete: onDelete,
          onClose: () => Navigator.pop(context),
          imageService: imageService,
        );
      },
    );
  }
}