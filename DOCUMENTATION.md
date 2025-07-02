# NCDC CCMS Mobile Application Documentation

This document provides a high-level overview of the NCDC CCMS mobile application, its architecture, and key implementation details. For a detailed log of the performance optimizations implemented, please see `PERFORMANCE_OPTIMIZATION_LOG.md`.

## 1. Application Overview

The NCDC Community Complaint Management System (CCMS) mobile application allows users to submit, view, and manage complaints related to city services. The application features a real-time map view of complaints, detailed complaint information, and administrative dashboards.

## 2. Core Technologies

- **Framework**: Flutter
- **Backend**: Supabase (Authentication, Database, Real-time Subscriptions, Storage)
- **Mapping**: Mapbox (via `mapbox_maps_flutter`)
- **State Management**: Provider

## 3. High-Level Architecture

The application is architected with a focus on performance, scalability, and separation of concerns.

### 3.1. Service Layer

All interactions with external services (like Supabase) are encapsulated within dedicated service classes.

- **`ComplaintService`**: Handles all CRUD operations and real-time subscriptions for complaints.
- **`ImageService`**: Manages uploading and retrieving complaint images from Supabase Storage.
- **`MapboxService`**: Encapsulates Mapbox-specific logic, such as styling, marker management, and camera control.

### 3.2. State Management

The `provider` package is used for dependency injection and state management.

- **`ComplaintProvider`**: Manages the state of complaints, handling real-time updates and providing data to the UI. It includes a robust retry mechanism for the real-time stream.
- **`PerformanceProvider`**: A global provider that monitors application performance (FPS) and enables intelligent, adaptive UI optimizations.

### 3.3. Performance Optimization Architecture

To ensure a smooth user experience, a dedicated performance optimization architecture has been implemented.

#### **a. Background Processing Pipeline**

- **File**: `lib/utils/background_processor.dart`
- **Functionality**: Offloads heavy, CPU-intensive tasks (like processing large sets of map markers) from the main UI thread to a background isolate.
- **Trigger**: Automatically used when processing datasets above a certain threshold (e.g., >10-20 items) to prevent UI jank.

#### **b. Intelligent Performance Monitoring**

- **File**: `lib/providers/performance_provider.dart`
- **Functionality**:
    - **Monitors FPS**: Tracks a rolling average of frames per second.
    - **Adaptive UI**: If performance degrades (e.g., FPS < 45), it triggers a "high-performance mode."
    - **Performance Mode**: In this mode, UI animations are reduced, rendering complexity is lowered, and interactions are debounced to preserve a responsive user experience on lower-end devices or during heavy processing.

## 4. Key Features & Implementation Notes

### 4.1. Real-time Map Screen

- **File**: `lib/map_screen/map_screen.dart`
- **Key Logic**:
    - **Safe Lifecycle Management**: The Mapbox widget is carefully managed to prevent crashes related to its controller being used after disposal.
    - **Background Marker Loading**: For large numbers of complaints, marker data is prepared in a background isolate to keep the map interactive.
    - **Adaptive Controls**: The map controls (`lib/map_screen/widgets/map_controls.dart`) adjust their appearance and behavior based on the `PerformanceProvider` to ensure responsiveness.

### 4.2. Real-time Data Synchronization

- **Files**: `lib/complaint_service.dart`, `lib/complaint_provider.dart`
- **Key Logic**:
    - The `ComplaintService` exposes a `Stream` of complaint data from Supabase.
    - The `ComplaintProvider` subscribes to this stream and includes an **exponential backoff retry mechanism**. If the real-time connection is lost, it will automatically attempt to reconnect with increasing delays, ensuring the application recovers gracefully from network issues.

## 5. Development Best Practices

- **Separation of Concerns**: Keep UI, business logic, and service interactions in separate files/classes.
- **Performance-Aware Widgets**: For complex widgets, consider using the `PerformanceAware` mixin to monitor build times.
- **Use the Background Processor**: For any data processing loop that handles more than 20-30 items, use `BackgroundProcessor.run` to avoid blocking the UI thread.
- **Check for Mounted Status**: In `StatefulWidget` classes, always check `if (mounted)` before calling `setState()` after an `await`.
- **Safe Disposal**: Ensure all controllers (`StreamSubscription`, `Timer`, etc.) are properly disposed of in the `dispose()` method.

This documentation provides a guide for maintaining and extending the NCDC CCMS application with a continued focus on performance and stability.

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