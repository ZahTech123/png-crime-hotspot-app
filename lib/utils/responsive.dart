import 'package:flutter/material.dart';

/// A utility class for handling responsive layouts in Flutter.
///
/// Provides static methods and constants to check screen size and orientation,
/// allowing widgets to adapt their layout accordingly.
class Responsive {
  // Define standard breakpoints for different screen sizes.
  // These values can be adjusted based on design requirements.
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900; // Example breakpoint, adjust as needed
  // static const double desktopBreakpoint = 1200; // Uncomment if desktop layout is distinct

  /// Checks if the current screen width is considered mobile size.
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  /// Checks if the current screen width is considered tablet size.
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobileBreakpoint &&
      MediaQuery.of(context).size.width < tabletBreakpoint;

  /// Checks if the current screen width is considered desktop size.
  /// Assumes anything >= tablet breakpoint might use a desktop layout if defined.
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint; 

  /// Gets the current screen orientation.
  static Orientation getOrientation(BuildContext context) =>
      MediaQuery.of(context).orientation;

  /// Checks if the current orientation is portrait.
  static bool isPortrait(BuildContext context) =>
      getOrientation(context) == Orientation.portrait;

  /// Checks if the current orientation is landscape.
  static bool isLandscape(BuildContext context) =>
      getOrientation(context) == Orientation.landscape;

  /// Returns the current screen width.
  static double screenWidth(BuildContext context) => MediaQuery.of(context).size.width;

  /// Returns the current screen height.
  static double screenHeight(BuildContext context) => MediaQuery.of(context).size.height;

  /// A convenience builder method to return different widgets based on screen width.
  ///
  /// Useful for swapping entire layout structures (e.g., Scaffold body).
  ///
  /// Example:
  /// ```dart
  /// Responsive.build(
  ///   context: context,
  ///   mobile: MobileLayout(),
  ///   tablet: TabletLayout(),
  ///   desktop: DesktopLayout(), // Optional
  /// )
  /// ```
  static Widget build({
    required BuildContext context,
    required Widget mobile,
    Widget? tablet, // Defaults to mobile layout if null
    Widget? desktop, // Defaults to tablet (if provided) or mobile layout if null
  }) {
    final double width = screenWidth(context);
    if (width >= tabletBreakpoint && desktop != null) {
      // If width is desktop size and desktop widget is provided
      return desktop;
    }
    if (width >= mobileBreakpoint && tablet != null) {
      // If width is tablet size and tablet widget is provided
      return tablet;
    }
    // Otherwise, return the mobile widget
    return mobile;
  }

  /// Selects a value based on the current screen width category.
  ///
  /// Useful for adjusting padding, font sizes, grid columns, etc.
  ///
  /// Example:
  /// ```dart
  /// int columns = Responsive.value<int>(context, mobile: 1, tablet: 2, desktop: 3);
  /// double padding = Responsive.value<double>(context, mobile: 8.0, tablet: 16.0);
  /// ```
  static T value<T>(BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
     final double width = screenWidth(context);
    if (width >= tabletBreakpoint && desktop != null) {
      // Use desktop value if available and screen is large enough
      return desktop;
    }
    if (width >= mobileBreakpoint && tablet != null) {
      // Use tablet value if available and screen is large enough
      return tablet;
    }
    // Default to mobile value
    return mobile;
  }
} 