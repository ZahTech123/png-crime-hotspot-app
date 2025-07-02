# Map Screen Functionality Documentation (`lib/map_screen.dart`)

This document outlines the key features and functionalities implemented in the `MapScreen` widget.

## Core Features

1.  **Map Display:** Uses the `mapbox_maps_flutter` package to render an interactive map, centered initially on Port Moresby. Includes 3D building rendering.
2.  **Supabase Integration:** Fetches complaint location data (latitude, longitude) from the `complaints` table in Supabase upon loading.
3.  **Marker Display:**
    *   Uses `PointAnnotationManager` to display markers on the map for each fetched complaint coordinate.
    *   Markers are represented by a custom image loaded from `assets/map-point.png`.
    *   The `image` property of `PointAnnotationOptions` is used, loading the image data directly.

## Dynamic Marker Sizing

*   The size of the markers (`iconSize`) dynamically adjusts based on the map's current zoom level.
*   This is handled by the `_onCameraChanged` listener, which triggers (with debouncing) when the map camera moves.
*   The `_calculateIconSize` helper function determines the appropriate size based on the zoom level (interpolating between min/max sizes and zooms).
*   The `PointAnnotationManager.update()` method is used to apply the new size to each existing annotation.

## Map Controls & Navigation

1.  **Zoom Buttons (+/-):**
    *   Standard zoom in and zoom out functionality.
    *   These buttons now *also* control the map's pitch: zooming in increases pitch (more tilt), zooming out decreases pitch (flatter).
2.  **Rotate Buttons (Left/Right):** Allow rotating the map's bearing.
3.  **Pitch Buttons (Up/Down):** Allow direct control over the map's tilt angle.
4.  **Previous/Next Marker Buttons (< / >):**
    *   Enabled only after marker data is loaded.
    *   Cycle through the locations of the complaint markers.
    *   Uses a **two-step animation** (`_flyToCoordinate`):
        1.  Calculates the center of all markers and animates to a forced zoomed-out (zoom: 6.0), flat (pitch: 0.0) view centered on that point. This animation is slightly slower (`1200ms`).
        2.  Animates from the overview into the specific target marker location with high zoom (18.5) and high pitch (70.0) (`1000ms`).
5.  **Home/Reset View Button (Home Icon):**
    *   Calculates the bounding box required to fit all currently loaded markers (`_complaintCoordinates`).
    *   Uses `mapboxMap.cameraForCoordinates` to determine the appropriate camera settings (center, zoom) to encompass all markers with padding.
    *   Animates the map to this calculated view.
    *   If no markers are loaded, it defaults to the initial Port Moresby view.

## Initial View

*   The initial map camera position is no longer fixed at the start.
*   Instead, after the complaint data is fetched and markers are added, the view automatically animates to fit all loaded markers using the same logic as the Home/Reset button.
*   If fetching fails or returns no results, the view defaults to the initial Port Moresby overview.

## Lifecycle & Safety

*   Uses a `SafeMapboxWidget` wrapper to help manage the Mapbox map lifecycle and prevent errors related to using disposed map instances.
*   Includes checks (`mounted`, `_isDisposed`) throughout asynchronous operations and callbacks to prevent errors if the widget is disposed prematurely.
*   Listeners (`onCameraChangeListener`) are added and removed appropriately.

---

## 🚀 Performance & Architecture Refactor

**Note:** The `MapScreen` has undergone a significant performance and architectural refactor to resolve startup performance issues. The original implementation caused major UI freezing due to synchronous data loading.

The new architecture utilizes a `FutureBuilder` pattern and a `MapController` to load all complaint data asynchronously *after* the initial UI has rendered. This has eliminated the startup lag and dramatically improved user experience.

**For a complete technical breakdown of this refactor, see the full report: [Performance Optimization Report (2024)](./performance_optimization_2024.md)** 