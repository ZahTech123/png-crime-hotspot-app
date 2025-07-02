# NCDC CCMS Mobile Application

This is the official Flutter-based mobile application for the NCDC Complaint and Case Management System (CCMS). The application allows for the viewing and management of city-wide complaints, with a focus on providing a real-time, map-based interface for response teams.

## Project Status & Architecture

This project has recently undergone a significant performance and architectural overhaul to address startup bottlenecks and improve maintainability.

-   **Architecture**: The application is moving towards a clean, layered architecture, separating UI, business logic, and data services. Key components like the Map Screen have been refactored for clarity and testability.
-   **Performance**: Initial synchronous data loading has been replaced with modern asynchronous patterns (`FutureBuilder`, lazy loading), eliminating UI freezing at startup and ensuring a responsive user experience.

For more detailed technical information, please see the [internal documentation](./docs/app_documentation.md).

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
