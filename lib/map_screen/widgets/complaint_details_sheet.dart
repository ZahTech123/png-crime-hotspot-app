import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Helper function to fetch full details for a single complaint
Future<Map<String, dynamic>?> _fetchComplaintDetails(String complaintId, BuildContext context) async {
  // No mounted check needed here as it's called from a context that should be mounted
  print("Fetching details for complaint ID: $complaintId");
  try {
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('complaints')
        .select() // Select all columns for details
        .eq('id', complaintId)
        .single(); // Expect only one row

    print("Successfully fetched details: ${response}");
    return response; // Supabase returns a Map<String, dynamic>
  } catch (e) {
    print("Error fetching complaint details: $e");
    // Optionally show a snackbar error here too
    if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching details: $e')),
        );
    }
    return null;
  }
}

class ComplaintDetailsSheet extends StatelessWidget {
  final String complaintId;

  const ComplaintDetailsSheet({Key? key, required this.complaintId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use a FutureBuilder to fetch data and display content
    return FutureBuilder<Map<String, dynamic>?>( // Expecting a single map or null
      future: _fetchComplaintDetails(complaintId, context),
      builder: (context, snapshot) {
        // --- Height constraint for the sheet content ---
        final screenHeight = MediaQuery.of(context).size.height;
        final sheetHeight = screenHeight * 0.6; // Example: 60% of screen height

        Widget content;
        if (snapshot.connectionState == ConnectionState.waiting) {
          content = const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          content = Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Error loading complaint details: ${snapshot.error ?? 'Data not found.'}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        } else {
          // Data fetched successfully
          final complaintData = snapshot.data!;
          content = SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Ensure column takes minimum space
              children: [
                Text('Complaint Details', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                Text('ID: ${complaintData['id'] ?? 'N/A'}'),
                const SizedBox(height: 8),
                Text('Type: ${complaintData['issue_type'] ?? 'N/A'}'),
                const SizedBox(height: 8),
                Text('Directorate: ${complaintData['directorate'] ?? 'N/A'}'),
                const SizedBox(height: 8),
                Text('Status: ${complaintData['status'] ?? 'N/A'}'),
                const SizedBox(height: 8),
                Text('Description: ${complaintData['description'] ?? 'N/A'}'),
                const SizedBox(height: 8),
                Text('Location: (${complaintData['latitude']}, ${complaintData['longitude']})'),
                // Add more fields as needed (e.g., images, timestamps)
              ],
            ),
          );
        }

        // Apply height constraint and padding for keyboard avoidance
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SizedBox(
            height: sheetHeight,
            child: content,
          ),
        );
      },
    );
  }
} 