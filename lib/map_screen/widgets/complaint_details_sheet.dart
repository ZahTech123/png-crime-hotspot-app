import 'package:flutter/material.dart';

class ComplaintDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> complaintData;

  const ComplaintDetailsSheet({super.key, required this.complaintData});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final sheetHeight = screenHeight * 0.6; // 60% of screen height

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Complaint Details', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          _buildDetailRow('ID', complaintData['id']?.toString() ?? 'N/A'),
          _buildDetailRow('Type', complaintData['issue_type'] ?? 'N/A'),
          _buildDetailRow('Directorate', complaintData['directorate'] ?? 'N/A'),
          _buildDetailRow('Status', complaintData['status'] ?? 'N/A'),
          _buildDetailRow('Description', complaintData['description'] ?? 'N/A'),
          _buildDetailRow('Location', 'Lat: ${complaintData['latitude']}, Lon: ${complaintData['longitude']}'),
          // Add more fields as needed
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: sheetHeight,
        child: content,
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 16, color: Colors.black87),
          children: [
            TextSpan(
              text: '$title: ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
} 