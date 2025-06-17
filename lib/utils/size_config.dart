import 'package:flutter/widgets.dart';

class SizeConfig {
  static late MediaQueryData _mediaQueryData;
  static late double screenWidth;
  static late double screenHeight;
  static late Orientation orientation;

  void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData.size.width;
    screenHeight = _mediaQueryData.size.height;
    orientation = _mediaQueryData.orientation;
  }
}

/// Helper function to get proportionate height as per screen size
/// [inputHeight] is the height on the designer's layout (e.g., Figma)
double getProportionateScreenHeight(double inputHeight) {
  // Use the screen height from SizeConfig
  double screenHeight = SizeConfig.screenHeight;
  // 812 is the layout height that designers often use for mobile designs.
  // You can adjust this value based on your specific design reference.
  return (inputHeight / 812.0) * screenHeight;
}

/// Helper function to get proportionate width as per screen size
/// [inputWidth] is the width on the designer's layout (e.g., Figma)
double getProportionateScreenWidth(double inputWidth) {
  // Use the screen width from SizeConfig
  double screenWidth = SizeConfig.screenWidth;
  // 375 is the layout width that designers often use for mobile designs.
  // You can adjust this value based on your specific design reference.
  return (inputWidth / 375.0) * screenWidth;
} 