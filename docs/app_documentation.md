# App Overview and Documentation

This document provides an overview of different components and features within the NCDC CCMS mobile application.

## Signed URLs for Private Image Storage

This document outlines the steps to secure images in your Supabase storage bucket (`complaintimages`) by making it private and using Signed URLs within your Flutter application. This ensures only authenticated users accessing your app can view the images, and only for a limited time.

**Current State:** The `complaintimages` bucket is set to "Public", and images are displayed using the direct public URL (`.../storage/v1/object/public/...`).

**Target State:** The `complaintimages` bucket will be private. Images will be displayed using temporary, secure Signed URLs generated on-demand by the Flutter app.

**Steps for Implementation:**

1.  **Make the Supabase Bucket Private:**
    *   Go to your Supabase Project Dashboard -> Storage -> `complaintimages` bucket.
    *   Click the "Settings" icon/tab for the bucket.
    *   **Disable** (uncheck) the "Public bucket" toggle.
    *   Save the changes.
    *   *(Optional but Recommended)*: Review your Storage Policies for the `complaintimages` bucket. Ensure you have appropriate RLS (Row Level Security) policies in place. A common policy allows authenticated users to `SELECT` (read) objects. You likely already have one for uploads (`INSERT`), but you might need to add or adjust one for reads if you haven't already. Example read policy for authenticated users:
        ```sql
        -- Policy Name: Allow authenticated read access
        CREATE POLICY "Allow authenticated read access"
        ON storage.objects FOR SELECT
        TO authenticated
        USING ( bucket_id = 'complaintimages' );
        ```

2.  **Modify Flutter Code to Generate and Use Signed URLs:**

    *   **Identify:** Locate the widget(s) in your Flutter code where you currently display complaint images using `Image.network()` with the direct public URL string fetched from your database.
    *   **Import:** Ensure you have the `supabase_flutter` package imported in that file.
    *   **Get Supabase Client:** Make sure you have access to the initialized `SupabaseClient` instance within your widget (you might get this via `Supabase.instance.client`, a Provider, or passed down the widget tree).
    *   **Implement Signed URL Generation:** Replace the direct URL usage with logic to generate a signed URL *before* building the `Image` widget. A `FutureBuilder` is often a good fit for this asynchronous operation.

    **Example (Conceptual - Adapt to your specific widget structure):**

    ```dart
    import 'package:flutter/material.dart';
    import 'package:supabase_flutter/supabase_flutter.dart';

    class ComplaintDetailWidget extends StatelessWidget {
      // Assume 'complaint' object has an 'imagePath' field like 'main_j749924795427_____.jpg'
      final Complaint complaint;

      const ComplaintDetailWidget({Key? key, required this.complaint}) : super(key: key);

      // --- Function to generate the Signed URL ---
      Future<String> _createSignedImageUrl(String imagePath) async {
        final supabase = Supabase.instance.client; // Get Supabase client
        const bucketName = 'complaintimages';
        // Set an appropriate expiry time (in seconds) - e.g., 1 hour
        final expiresIn = 60 * 60;

        try {
          final String signedUrl = await supabase.storage
              .from(bucketName)
              .createSignedUrl(imagePath, expiresIn);
          return signedUrl;
        } on StorageException catch (error) {
          // Handle specific storage errors (e.g., object not found, access denied)
          print('Storage Error creating signed URL: ${error.message}');
          // Return a placeholder URL or rethrow, depending on desired UX
          return 'https://via.placeholder.com/150?text=Error'; // Example placeholder
        } catch (error) {
          // Handle other potential errors
          print('Generic Error creating signed URL: $error');
          return 'https://via.placeholder.com/150?text=Error'; // Example placeholder
        }
      }
      // ------------------------------------------

      @override
      Widget build(BuildContext context) {
        return Scaffold(
          appBar: AppBar(title: Text('Complaint Details')),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Complaint ID: ${complaint.id}'),
                // ... other complaint details ...
                SizedBox(height: 20),
                Text('Image:', style: Theme.of(context).textTheme.headline6),
                SizedBox(height: 10),

                // --- Use FutureBuilder to display the image ---
                if (complaint.imagePath != null && complaint.imagePath!.isNotEmpty)
                  FutureBuilder<String>(
                    // Call the function to get the signed URL
                    future: _createSignedImageUrl(complaint.imagePath!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        // Show loading indicator while URL is generated
                        return Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.startsWith('http') == false) {
                        // Show error placeholder if URL generation failed or is invalid
                        print('Error in FutureBuilder: ${snapshot.error}');
                        return Center(child: Icon(Icons.error_outline, color: Colors.red, size: 50));
                        // Or return Image.network('placeholder_url_if_you_have_one');
                      } else {
                        // --- Display the image using the generated Signed URL ---
                        final signedImageUrl = snapshot.data!;
                        return Image.network(
                          signedImageUrl,
                          fit: BoxFit.cover, // Adjust fit as needed
                          // Optional: Add loading builder for Image.network itself
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          // Optional: Add error builder for Image.network
                          errorBuilder: (context, error, stackTrace) {
                            print('Image.network error: $error');
                            return Center(child: Icon(Icons.broken_image, size: 50));
                          },
                        );
                        // ----------------------------------------------------------
                      }
                    },
                  )
                else
                  Text('No image associated with this complaint.'),
                // ------------------------------------------------

              ],
            ),
          ),
        );
      }
    }

    // Dummy Complaint class for example
    class Complaint {
      final String id;
      final String? imagePath; // e.g., 'folder/image_name.jpg' or just 'image_name.jpg'
      // ... other fields
      Complaint({required this.id, this.imagePath});
    }
    ```

3.  **Testing:**
    *   Thoroughly test the image display functionality for logged-in users.
    *   Verify that images load correctly.
    *   Try accessing an image's *old* public URL directly in a browser – it should now fail (likely with an authorization error or "object not found" if RLS prevents access).
    *   Test edge cases (e.g., complaints with no images, slow network connections).

By following these steps, you can transition to a more secure method of handling images in your city management application whenever you are ready. Remember to replace placeholder/example code with your actual variable names and data structures.

---

## Reports Page (`lib/reports_page.dart`)

This page provides a dashboard view of aggregated complaint data, aimed at giving the response team insights into current trends and workloads.

**Purpose:**
To visualize key metrics about complaints using charts and summary cards (KPIs).

**Data Source:**
The `ReportsPage` utilizes the `ComplaintProvider` to access the list of complaints. It uses `context.watch<ComplaintProvider>()` to listen for changes in the provider's state (loading status, errors, and the complaints list) and rebuilds automatically when the data updates.

**Key Features:**

*   **KPI Cards:** Displays key performance indicators:
    *   *Open Complaints:* Count of complaints not 'Resolved' or 'Closed'.
    *   *Total Complaints:* Total number of complaints loaded.
*   **Charts:**
    *   *Complaints by Status:* A `PieChart` showing the distribution of complaints based on their `status` (New, In Progress, Resolved, Closed).
    *   *Complaints by Priority:* A `BarChart` showing the count of complaints for each `priority` level (Critical, High, Medium, Low).
    *   *Complaints by Directorate:* A `BarChart` displaying the number of complaints associated with each directorate.
*   **Refresh Functionality:**
    *   Supports pull-to-refresh on the main view.
    *   Includes a refresh `IconButton` in the `AppBar`.
    *   Both refresh actions trigger the `refreshComplaints()` method on the `ComplaintProvider`.
*   **State Handling:**
    *   Displays a `CircularProgressIndicator` while the `ComplaintProvider` is loading data (`provider.isLoading`).
    *   Shows an error message if the `ComplaintProvider` reports an error (`provider.errorMessage`).
    *   Displays a "No complaint data available" message (with a refresh button) if the provider has finished loading but the complaints list is empty.

**Libraries Used:**

*   `provider`: For state management and accessing data from `ComplaintProvider`.
*   `fl_chart`: For rendering the Pie and Bar charts.
*   `intl`: Used internally by charts for potential formatting (though not heavily used in current charts).

**Structure & Implementation Notes:**

The `ReportsPage` itself is stateless regarding the *data* it displays. It relies entirely on the state exposed by `ComplaintProvider`. The `build` method watches the provider and passes the necessary state (`isLoading`, `errorMessage`, `complaints`) down to specific builder methods (`_buildKPIs`, `_buildStatusChart`, etc.). Data aggregation logic (e.g., `_getComplaintCountsByStatus`) is kept within the `ReportsPage` state but operates on the complaint list received from the provider.

## Map Screen (`lib/map_screen.dart`)

This screen provides an interactive map view displaying the geographical location of reported complaints.

**For a detailed breakdown of the Map Screen architecture, see: [Map Screen Documentation](./map_screen_documentation.md)**

---

## 🚀 Performance Optimization

A major performance overhaul was completed to address significant startup lag and UI freezing. The application's data loading architecture was refactored to be fully asynchronous.

**For a complete analysis and breakdown of the implemented fixes, see the full report: [Performance Optimization Report (2024)](./performance_optimization_2024.md)** 