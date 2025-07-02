# Setting up a 3D Mapbox Map in Flutter

This document explains how to create a Flutter application displaying a 3D map with building extrusions using the `mapbox_maps_flutter` package, based on the example code provided.

## 1. Prerequisites

*   A Flutter development environment set up.
*   A Mapbox Access Token. You can create one on the [Mapbox website](https://www.mapbox.com/).

## 2. Project Setup

*   Add the `mapbox_maps_flutter` dependency to your `pubspec.yaml` file:
    ```yaml
    dependencies:
      flutter:
        sdk: flutter
      mapbox_maps_flutter: ^latest_version # Use the latest version
    ```
*   Run `flutter pub get` to install the package.

## 3. Implementation Steps

### a. Initialization (main.dart)

*   **Import necessary packages:**
    ```dart
    import 'package:flutter/material.dart';
    import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
    ```
*   **Initialize Flutter bindings:** Ensure Flutter is ready before running the app.
    ```dart
    WidgetsFlutterBinding.ensureInitialized();
    ```
*   **Set Mapbox Access Token:** Provide your access token to the Mapbox SDK. **Important:** For production apps or public repositories, avoid hardcoding the token directly. Use environment variables (`--dart-define`) or other secure methods.
    ```dart
    MapboxOptions.setAccessToken("YOUR_MAPBOX_ACCESS_TOKEN"); // Replace with your actual token or use a secure method
    ```
*   **Run the App:** Start the Flutter application with your map widget as the home screen.
    ```dart
    runApp(MaterialApp(home: BuildingExtrusionsExample()));
    ```

### b. Map Widget Implementation (BuildingExtrusionsExample Widget)

*   **Create a StatefulWidget:** This allows managing the map's state, including the `MapboxMap` controller.
    ```dart
    class BuildingExtrusionsExample extends StatefulWidget {
      @override
      State createState() => BuildingExtrusionsExampleState();
    }

    class BuildingExtrusionsExampleState extends State<BuildingExtrusionsExample> {
      MapboxMap? mapboxMap;
      // ... rest of the state class
    }
    ```
*   **Implement `_onMapCreated`:** This callback receives the `MapboxMap` controller when the map is initialized. Store it for later use (e.g., adding layers).
    ```dart
    _onMapCreated(MapboxMap mapboxMap) {
      this.mapboxMap = mapboxMap;
    }
    ```
*   **Implement `_onStyleLoadedCallback`:** This callback is crucial. It fires *after* the base map style (like `MapboxStyles.LIGHT`) has finished loading. This is the correct place to add custom layers like 3D buildings, ensuring the necessary sources are available.
    ```dart
    _onStyleLoadedCallback(StyleLoadedEventData data) {
      // Add 3D buildings layer after the style is loaded
      _add3DBuildings();
    }
    ```
*   **Add the `MapWidget` to the `build` method:**
    ```dart
    @override
    Widget build(BuildContext context) {
      return Scaffold(
        body: MapWidget(
          key: ValueKey("mapWidget"), // Unique key
          cameraOptions: CameraOptions(
            center: Point(coordinates: Position(-74.0066, 40.7135)), // Initial location (e.g., New York City)
            pitch: 45.0, // Tilt the map (essential for seeing 3D)
            zoom: 16.0,   // Initial zoom level
            bearing: -17.6, // Initial map rotation
          ),
          styleUri: MapboxStyles.LIGHT, // Base map style
          textureView: true, // Recommended for performance on Android
          onMapCreated: _onMapCreated,
          onStyleLoadedListener: _onStyleLoadedCallback,
        ),
      );
    }
    ```
    *   `cameraOptions`: Sets the initial view. `pitch` greater than 0 tilts the map for a 3D perspective.
    *   `styleUri`: Defines the base map appearance. Styles like `LIGHT`, `DARK`, `STREETS`, etc., often contain the necessary 'composite' source used for buildings.
    *   `onMapCreated`: Callback for map initialization.
    *   `onStyleLoadedListener`: Callback for when the base style is ready.

### c. Adding 3D Buildings Layer (`_add3DBuildings` method)

*   **Define the layer adding function:** This function creates and adds the `FillExtrusionLayer`.
    ```dart
    void _add3DBuildings() {
      // Check if mapboxMap is initialized
      if (mapboxMap == null) return;

      // Create a fill extrusion layer for buildings
      final fillExtrusionLayer = FillExtrusionLayer(
        id: "3d-buildings",          // Unique ID for the layer
        sourceId: "composite",       // Source containing building data (common in Mapbox styles)
        sourceLayer: "building",     // Specific layer within the source
        minZoom: 15.0,               // Minimum zoom level to show the layer
        filter: ["==", "extrude", "true"], // Only show features marked for extrusion
        fillExtrusionColor: Colors.grey.value, // Building color
        // Use data properties for height and base:
        fillExtrusionHeightExpression: ["get", "height"], // Get height from feature properties
        fillExtrusionBaseExpression: ["get", "min_height"], // Get base height from feature properties
        fillExtrusionOpacity: 0.6,   // Opacity of the buildings
        fillExtrusionAmbientOcclusionIntensity: 0.3, // Adds subtle shading for depth
      );

      // Add the layer to the map's style
      mapboxMap?.style.addLayer(fillExtrusionLayer);
    }
    ```
    *   `FillExtrusionLayer`: The specific layer type for creating 3D polygons.
    *   `sourceId` & `sourceLayer`: Point to the vector tile data containing building geometries and properties. `composite` is common in default Mapbox styles.
    *   `filter`: Ensures only features intended for extrusion (like buildings) are rendered.
    *   `fillExtrusionHeightExpression`: Crucial for 3D. Uses a Mapbox expression `["get", "height"]` to dynamically set the extrusion height based on the `height` property of each building feature in the data source.
    *   `fillExtrusionBaseExpression`: Similar to height, sets the base height using the `min_height` property, useful for buildings on varied terrain.
    *   Other properties control appearance (color, opacity, ambient occlusion).

## 4. Full Example Code (`lib/main.dart`)

```dart
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Pass your access token to MapboxOptions
  // IMPORTANT: Replace with your token or use a secure method like --dart-define
  MapboxOptions.setAccessToken("YOUR_MAPBOX_ACCESS_TOKEN"); 

  runApp(MaterialApp(home: BuildingExtrusionsExample()));
}

class BuildingExtrusionsExample extends StatefulWidget {
  @override
  State createState() => BuildingExtrusionsExampleState();
}

class BuildingExtrusionsExampleState extends State<BuildingExtrusionsExample> {
  MapboxMap? mapboxMap;

  _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
  }

  _onStyleLoadedCallback(StyleLoadedEventData data) {
    // Add 3D buildings layer after the style is loaded
    _add3DBuildings();
  }

  void _add3DBuildings() {
     if (mapboxMap == null) return;
     
    // Create a fill extrusion layer for buildings
    final fillExtrusionLayer = FillExtrusionLayer(
      id: "3d-buildings",
      sourceId: "composite",
      sourceLayer: "building",
      minZoom: 15.0,
      filter: ["==", "extrude", "true"],
      fillExtrusionColor: Colors.grey.value,
      fillExtrusionHeightExpression: ["get", "height"],
      fillExtrusionBaseExpression: ["get", "min_height"],
      fillExtrusionOpacity: 0.6,
      fillExtrusionAmbientOcclusionIntensity: 0.3,
    );

    mapboxMap?.style.addLayer(fillExtrusionLayer);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MapWidget(
        key: ValueKey("mapWidget"),
        cameraOptions: CameraOptions(
          center: Point(coordinates: Position(-74.0066, 40.7135)), // New York City
          pitch: 45.0, // Tilt the map to see 3D buildings
          zoom: 16.0,
          bearing: -17.6,
        ),
        styleUri: MapboxStyles.LIGHT,
        textureView: true,
        onMapCreated: _onMapCreated,
        onStyleLoadedListener: _onStyleLoadedCallback,
      ),
    );
  }
}
```

## 5. Running the App

Ensure you have replaced `"YOUR_MAPBOX_ACCESS_TOKEN"` with your actual token or configured it via `--dart-define` like this:

```bash
flutter run --dart-define=ACCESS_TOKEN=YOUR_MAPBOX_ACCESS_TOKEN
```

(If using `--dart-define`, adjust the `main` function accordingly to read the token from the environment).

The app should launch, show a map centered on New York City (or your chosen coordinates), tilted to a 45-degree angle, and render 3D buildings once zoomed in past level 15. 