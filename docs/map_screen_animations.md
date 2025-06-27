# Map Screen (`lib/map_screen.dart`) Animation Documentation

This document describes the custom animation features implemented in the `MapScreen` widget, focusing on marker navigation and camera controls.

## Overview

The `MapScreen` displays a Mapbox map centered on Port Moresby, showing complaint locations fetched from Supabase as markers. It provides various controls for navigating the map and cycling through markers, featuring custom animations for a smoother user experience.

## SafeMapboxWidget Wrapper

The `MapWidget` from the `mapbox_maps_flutter` package is wrapped within a custom `SafeMapboxWidget`. This wrapper ensures proper lifecycle management, particularly handling the disposal of the Mapbox map instance to prevent potential memory leaks or crashes, especially during screen navigation. It forwards the necessary callbacks (`onMapCreated`, `onStyleLoadedListener`, `onCameraChangeListener`) to the `_MapScreenState`.

## Marker Navigation (`_flyToCoordinate`)

When the user clicks the "Next" or "Previous" marker buttons (`_goToNextMarker`, `_goToPreviousMarker`), the `_flyToCoordinate` function executes a multi-step animation sequence:

1.  **Step 1: Zoom Out**
    *   **Purpose:** Provides context by briefly showing a wider view.
    *   **Action:** Calculates the camera position needed to view all markers (`cameraForCoordinates`) but overrides the zoom and pitch.
    *   **Parameters:**
        *   `zoom`: 9.0 (relatively low zoom level)
        *   `pitch`: 0.0 (flat, top-down view)
        *   `bearing`: 0.0 (North-up orientation)
    *   **Duration:** 2000ms (2 seconds) - Increased duration contributes to a smoother perceived easing effect.

2.  **Step 2: Pause**
    *   **Purpose:** Creates a deliberate separation between the zoom-out and zoom-in phases.
    *   **Action:** Uses `Future.delayed`.
    *   **Duration:** 2000ms (2 seconds).

3.  **Step 3: Zoom In**
    *   **Purpose:** Focuses on the target marker.
    *   **Action:** Animates the camera to the specific marker's coordinates.
    *   **Parameters:**
        *   `center`: Coordinates of the target marker.
        *   `zoom`: 18.5 (high zoom level for close-up)
        *   `pitch`: 70.0 (high pitch for a 3D perspective)
        *   `bearing`: 45.0 (adds rotation during the zoom-in)
    *   **Duration:** 3000ms (3 seconds) - Significantly increased duration creates a very gradual, smooth arrival ("ease-in") at the marker.

## Camera Controls (Rotation & Pitch)

The standard rotation (`_rotateLeft`, `_rotateRight`) and pitch (`_increasePitch`, `_decreasePitch`) functions have been enhanced for a smoother experience:

*   **Increased Increment:**
    *   `_bearingIncrement`: Changed from 15.0 to `30.0` degrees per click for more noticeable rotation.
    *   `_pitchIncrement`: Changed from 5.0 to `10.0` degrees per click for more noticeable tilting.
*   **Increased Animation Duration:**
    *   The `flyTo` calls within all four rotation and pitch functions now use a fixed `duration` of `800ms`. This replaces the previous shorter duration (`_animationDurationMs = 300ms`).
    *   The longer duration makes the animation appear smoother and provides a more pronounced "ease-in-out" effect inherent in the `flyTo` function.
*   **Pitch Clamping:**
    *   `_increasePitch`: Uses `min(_maxPitch, ...)` to prevent pitching beyond the defined `_maxPitch` (70.0 degrees).
    *   `_decreasePitch`: Uses `max(0.0, ...)` to prevent pitching below 0.0 degrees. This ensures the map smoothly stops tilting when it reaches the flat, horizontal view, rather than attempting to go further.

## Other Related Features

*   **Dynamic Marker Sizing:** The `_onCameraChanged` listener (debounced) adjusts marker size based on zoom level using `_calculateIconSize` for better visibility.
*   **Reset View (`_resetCameraView`):** Animates the camera to fit all loaded markers or returns to the default initial view if no markers are present. Uses a duration of 1500ms.
*   **3D Buildings:** A `FillExtrusionLayer` is added in `_onStyleLoadedCallback` to display 3D building data from the Mapbox style.
*   **Error Handling & Lifecycle:** Includes checks for `mounted` and `_isDisposed` throughout async operations and uses `WillPopScope` with `_prepareForNavigation` for safer screen transitions. 