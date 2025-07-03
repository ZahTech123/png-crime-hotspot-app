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

## Recent Updates - Phase 1: Context Handling Improvements

### Overview
Fixed critical issues with the camera reset functionality (home button) by implementing proper context handling throughout the map architecture.

### Problems Solved
1. **Context Loss**: Fixed `resetCameraView` method receiving `null` context, which caused fallback to hardcoded screen dimensions
2. **Inconsistent Context Passing**: Updated all `resetCameraView` calls to pass proper context when available
3. **Architecture Mismatch**: Adapted context handling for the service-based architecture

### Changes Made

#### MapController Updates
- Added `_currentContext` tracking for proper camera operations
- Added `updateContext()` and `clearContext()` methods for lifecycle management
- Modified `resetCameraView()` to use stored context when available
- Updated all internal `resetCameraView` calls to pass proper context
- Restored missing 3D buildings setup and marker click listener initialization

#### MapboxService Enhancements
- Improved `resetCameraView()` method with robust context handling
- Added intelligent fallback mechanisms for when context is unavailable
- Implemented `SimpleBounds` class for simple bounds calculation
- Added dynamic padding calculation based on actual screen dimensions
- Enhanced error handling with multiple fallback strategies
- Added minimum zoom level enforcement for better UX

#### MapScreen Integration
- Added context updating in `_onMapCreated()` method
- Added context updating in `build()` method to ensure current context
- Added context clearing in `dispose()` method to prevent memory leaks
- Maintained proper context passing in MapControls integration

### Technical Improvements

#### Context Management
```dart
// Controller now tracks context for camera operations
void updateContext(BuildContext context) {
  _currentContext = context;
}

// Smart context usage in camera reset
final contextToUse = context ?? _currentContext;
await _mapboxService.resetCameraView(
  state.complaintCoordinates, 
  contextToUse, 
  isBottomSheetVisible: state.isBottomSheetVisible
);
```

#### Enhanced Camera Reset Logic
```dart
// Dynamic padding based on screen size
final paddingValue = screenSize.width * 0.05; // 5% of screen width
final topPadding = (screenPadding.top + appBarHeight) + paddingValue;
final bottomPadding = bottomSheetHeight + paddingValue;

// Fallback for when context is unavailable
const fallbackWidth = 375.0; // iPhone 13 mini width
const fallbackHeight = 812.0; // iPhone 13 mini height
```

#### Multi-Level Fallback Strategy
1. **Primary**: Use provided context with actual screen dimensions
2. **Secondary**: Use stored context if available
3. **Tertiary**: Use fallback mobile screen dimensions
4. **Final**: Use simple bounds calculation or default location

### Expected Results
- Camera reset (home button) now properly encompasses all markers
- Proper padding calculation prevents markers from being hidden under UI elements
- Smooth animations with appropriate zoom levels
- Robust error handling prevents crashes
- Better UX with consistent behavior across different screen sizes

## Enhanced Padding Implementation ✅

### Overview
Further improved the camera reset functionality with **enhanced padding calculations** to ensure markers are never positioned at the edge of the map view.

### Padding Enhancements Made

#### **Dynamic Padding Calculation**
```dart
// Enhanced padding - 12% of screen width (increased from 5%)
final horizontalPadding = screenSize.width * 0.12;
final basePadding = screenSize.height * 0.08; // 8% of screen height

// Asymmetric padding to account for UI elements
final leftPadding = horizontalPadding + 80.0;  // Extra space for map controls
final rightPadding = horizontalPadding + 20.0; // Standard right space
final topPadding = screenPadding.top + appBarHeight + basePadding + 20.0;
final bottomPadding = bottomSheetHeight + basePadding + 60.0;
```

#### **Fallback Padding** (when context unavailable)
```dart
const baseFallbackPadding = 60.0;        // Increased from 40.0
const leftExtraPadding = 100.0;          // Space for left-side controls
const topExtraPadding = 80.0;            // Space for app bar
const bottomExtraPadding = 80.0;         // Space for bottom sheet + controls
```

#### **Smart Zoom Level Adjustment**
- **Single marker**: Zoom level 14.0 for comfortable viewing
- **2-3 markers**: Zoom level 10.0-16.0 (clamped for visibility)
- **4-10 markers**: Zoom level 8.0-14.0 (moderate overview)
- **11+ markers**: Zoom level 6.0-12.0 (wide overview)
- **Padding compensation**: Additional -0.5 zoom reduction to accommodate extra padding

#### **Marker Count Optimization**
```dart
// Adjust zoom based on marker density
if (coordinates.length > 20) {
  suggestedZoom = suggestedZoom - 1.0;      // Wide overview for many markers
} else if (coordinates.length > 10) {
  suggestedZoom = suggestedZoom - 0.5;      // Moderate adjustment
}
```

### Key Improvements
1. **🎯 Better Marker Visibility**: Markers now have substantial breathing room from all edges
2. **🖥️ UI Element Awareness**: Extra padding accounts for map controls, app bar, and bottom sheet
3. **📱 Asymmetric Padding**: More space on the left side where map controls are located
4. **🔍 Smart Zoom Levels**: Zoom automatically adjusts based on marker count and spread
5. **⚡ Enhanced Fallbacks**: Generous fallback padding even when screen context is unavailable

### Technical Details
- **Horizontal padding**: Increased from 5% to 12% of screen width
- **Vertical padding**: 8% of screen height as base + UI element heights
- **Control compensation**: +80px left padding for map controls
- **Bottom sheet compensation**: +60px bottom padding when sheet is visible
- **Zoom compensation**: -0.5 zoom level to accommodate increased padding space

### Next Steps
- Phase 2: Improve Camera Reset Logic (enhanced bounds calculation)
- Phase 3: Add Debug and Validation (logging and user feedback)
- Phase 4: Testing and Optimization (performance improvements)

### Testing Recommendations
1. Test camera reset with various numbers of markers
2. Test on different screen sizes and orientations
3. Verify proper behavior when bottom sheet is visible/hidden
4. Test network error scenarios and fallback behavior 

#### **Better User Experience**
- **Consistent behavior**: Works reliably across different screen sizes and orientations
- **Smooth animations**: 1.5-second camera transitions with proper easing
- **Visual feedback**: Loading states and error handling
- **Robust error handling**: Multiple fallback mechanisms prevent crashes

#### **Performance Optimizations**
- **Smart zoom calculation**: Optimal zoom levels based on marker count
- **Responsive padding**: Adapts to different screen sizes and UI elements
- **Efficient bounds calculation**: Fast coordinate processing with fallback methods

---

## Phase 3: Debug and Validation - Complete! ✅

### Overview
Added comprehensive debugging and validation system to monitor camera operations and provide real-time troubleshooting capabilities.

### Key Features Implemented

#### **🔍 Comprehensive Logging System**
- ✅ **MapboxService Logging**: Every camera operation logged with detailed information
- ✅ **Performance Metrics**: Duration tracking for all camera movements  
- ✅ **Error Tracking**: Detailed error messages for failed operations
- ✅ **Context Validation**: Tracks context availability for each operation

#### **🛠️ Debug Helper Integration**
```dart
// Automatically enabled in debug mode
MapDebugHelper.setDebugEnabled(true);
```

**Features:**
- ✅ **Operation History**: Tracks last 50 camera operations
- ✅ **Failure Analysis**: Identifies patterns in failed operations
- ✅ **Performance Monitoring**: Tracks operation duration and zoom levels
- ✅ **Real-time Validation**: Validates coordinates and camera state

#### **📊 Enhanced Validation**
- ✅ **Coordinate Validation**: Checks for NaN, infinity, and valid lat/lng bounds
- ✅ **Context Validation**: Ensures proper screen dimension calculation
- ✅ **Camera State Validation**: Validates zoom levels and camera options
- ✅ **Pre-operation Checks**: Validates state before attempting camera movements

#### **🎯 User Feedback System**
- ✅ **Success Notifications**: Brief confirmation when camera reset succeeds
- ✅ **Error Notifications**: Clear error messages for failed operations
- ✅ **Loading States**: Visual feedback during camera operations
- ✅ **Non-intrusive Design**: Floating snackbars that don't block interaction

#### **📈 Debug Reporting**
```dart
// Generate comprehensive debug report
final report = MapDebugHelper.generateDebugReport();
```

**Report Contents:**
- ✅ **Operation Summary**: Total operations and failure count
- ✅ **Recent Operations**: Last 10 camera operations with status
- ✅ **Failed Operations**: Detailed error analysis for troubleshooting
- ✅ **Performance Data**: Duration and zoom level tracking

### Debug Logging Examples

#### **Successful Operation:**
```
[MapboxService] Starting camera reset operation
[MapboxService] Coordinates count: 5
[MapboxService] Context available: true
[MapboxService] Debug validation: Camera state is valid
[MapboxService] Screen size: 375.0x812.0
[MapboxService] Padding: T:140.0, L:125.0, B:124.8, R:65.0
[MapboxService] Zoom calculation: 12.5 -> 12.0 (Few markers (5): clamped to 8.0-14.0, -0.5 for padding compensation)
[MapboxService] Camera reset completed successfully in 1247ms
[Performance] resetCameraView: 1247ms, coords: 5, zoom: 12.0
```

#### **Fallback Operation:**
```
[MapboxService] Camera reset failed: Invalid camera bounds
[MapboxService] Attempting fallback camera reset
[MapboxService] Using simple bounds: center(147.1803, -9.4438), zoom: 10.0
[MapboxService] Fallback camera reset successful
```

### Expected Results
✅ **Reliable Debugging**: Every camera operation is tracked and logged  
✅ **Quick Troubleshooting**: Failed operations provide detailed error information  
✅ **Performance Insights**: Track camera operation performance over time  
✅ **User Feedback**: Clear notifications about camera reset status  
✅ **Validation Checks**: Prevent invalid operations before they cause issues  

## Next Phase
Ready for **Phase 4: Testing and Optimization** - Comprehensive testing and final performance optimizations. 