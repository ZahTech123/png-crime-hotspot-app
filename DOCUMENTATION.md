# Project Documentation

This file documents significant changes and architectural decisions made during the development of the NCDC CCMS Mobile Application.

## Attachment Handling Update (YYYY-MM-DD)

**Change:** Modified the `CityComplaint` model to store detailed attachment metadata instead of just image URLs.

**Files Affected:**

*   `lib/models.dart`:
    *   Added `final List<Map<String, dynamic>>? attachmentsData;` field.
    *   Updated the constructor, `fromJson`, `toJson`, and `copyWith` methods to include `attachmentsData`.
    *   The `fromJson` expects the data under the key `'attachments_data'`.
    *   The `toJson` outputs the data under the key `'attachments_data'`.
*   `lib/edit_complaint_dialog.dart`:
    *   Updated the logic in `_updateComplaint` to fetch existing attachments from `widget.complaint.attachmentsData`.
    *   Updated the call to `widget.complaint.copyWith` to pass the combined list of existing and new attachment metadata to the `attachmentsData` parameter.

**Reasoning:**

The previous implementation only stored a list of image URLs (`imageUrls`). This change was made to allow storing richer information about *all* types of attachments (including PDFs, etc.), such as the original filename, MIME type, file size, and storage path. This provides more flexibility for displaying and managing attachments in the UI and potentially for backend processes.

**Impact:**

*   The database schema for the `complaints` table needs a corresponding column (e.g., `attachments_data` of type `JSONB` or similar in Supabase/Postgres) to store this list of maps.
*   Code that reads or displays complaint data should now look at the `attachmentsData` field for comprehensive attachment information, rather than just `imageUrls`.

## Attachment Handling Refactor (Date of Change - e.g., 2024-07-30)

**Change:** Refactored attachment handling to store metadata directly within the `complaints` table, removing the separate `attachments` table.

**Database Schema Changes:**

*   **Dropped Table:** The `public.attachments` table was dropped.
*   **Dropped Policies:** Related RLS policies on `storage.objects` that depended on `public.attachments` were dropped (e.g., `"Allow download based on public.attachments RLS"`).
*   **Added Column:** A new column `attachments_data` of type `JSONB` was added to the `public.complaints` table.
*   **Column Purpose:** This `attachments_data` column stores an array (list) of maps, where each map represents an attachment and contains keys like `storage_path`, `file_name`, `mime_type`, `size`, `uploaded_at`.
    *   Example structure: `[{"storage_path": "complaint_id/timestamp_filename.jpg", "file_name": "photo.jpg", ...}, ...]`

**Files Affected:**

*   `lib/models.dart` (`CityComplaint` class):
    *   Ensured the `attachmentsData` field (`List<Map<String, dynamic>>?`) exists.
    *   Confirmed `fromJson`, `toJson` (if used), and `copyWith` handle this field correctly, mapping to/from the `attachments_data` JSON key.
*   `lib/edit_complaint_dialog.dart` (`_updateComplaint` function):
    *   Removed logic that inserted into the `public.attachments` table.
    *   Uploads files to Supabase Storage (`attachments` bucket).
    *   Prepares a metadata `Map` for each uploaded file.
    *   Reads the existing list from `widget.complaint.attachmentsData`.
    *   Appends the new metadata maps to the existing list.
    *   Calls `complaintProvider.updateComplaint`, passing the combined list via the `attachmentsData` field in the `copyWith` method, which ultimately updates the `attachments_data` JSONB column in the `complaints` table.

**Reasoning:**

*   Simplified the database schema by removing a table and foreign key relationship.
*   Consolidated complaint-related data into a single table row.
*   Relies on the RLS policies defined directly on the `complaints` table for controlling access to attachment metadata (as it's now just another column on that table).

**Impact & Considerations:**

*   The RLS policies on the `complaints` table now implicitly control who can add/modify/view attachment metadata. Currently, the `UPDATE` policy (`"Allow authenticated users to update complaints"`) is permissive, allowing any authenticated user to modify the `attachments_data` column along with other complaint fields.
*   UI code displaying attachments needs to read the list of maps from the `complaint.attachmentsData` field.
*   Code generating download/view URLs for attachments needs to get the `storage_path` from the maps within the `complaint.attachmentsData` list.

--- 