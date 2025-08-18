import 'package:flutter/material.dart';

/// Utility class for responsive text and font sizing across different devices
class ResponsiveText {
  /// Base text scale factor that can be adjusted based on screen size
  static double getTextScaleFactor(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Base scale factors for different screen sizes
    if (screenWidth < 360) {
      // Small phones (like iPhone SE)
      return 0.9;
    } else if (screenWidth < 400) {
      // Standard phones
      return 1.0;
    } else if (screenWidth < 600) {
      // Large phones
      return 1.1;
    } else {
      // Tablets
      return 1.2;
    }
  }
  
  /// Get responsive font size that respects user's accessibility settings
  static double getResponsiveFontSize(BuildContext context, double baseFontSize) {
    final scaleFactor = getTextScaleFactor(context);
    final accessibilityScaleFactor = MediaQuery.of(context).textScaleFactor;
    
    // Combine responsive scaling with accessibility scaling
    // But cap the maximum to prevent UI breaking
    final combinedScale = scaleFactor * accessibilityScaleFactor;
    final cappedScale = combinedScale.clamp(0.8, 2.5);
    
    return baseFontSize * cappedScale;
  }
  
  /// Text style that automatically adjusts to screen size and accessibility settings
  static TextStyle getResponsiveTextStyle(
    BuildContext context, {
    required double baseFontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontSize: getResponsiveFontSize(context, baseFontSize),
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }
  
  /// Pre-defined responsive text styles for common use cases
  static TextStyle heading1(BuildContext context, {Color? color}) {
    return getResponsiveTextStyle(
      context,
      baseFontSize: 32,
      fontWeight: FontWeight.bold,
      color: color,
    );
  }
  
  static TextStyle heading2(BuildContext context, {Color? color}) {
    return getResponsiveTextStyle(
      context,
      baseFontSize: 24,
      fontWeight: FontWeight.bold,
      color: color,
    );
  }
  
  static TextStyle heading3(BuildContext context, {Color? color}) {
    return getResponsiveTextStyle(
      context,
      baseFontSize: 20,
      fontWeight: FontWeight.w600,
      color: color,
    );
  }
  
  static TextStyle bodyLarge(BuildContext context, {Color? color}) {
    return getResponsiveTextStyle(
      context,
      baseFontSize: 16,
      color: color,
    );
  }
  
  static TextStyle bodyMedium(BuildContext context, {Color? color}) {
    return getResponsiveTextStyle(
      context,
      baseFontSize: 14,
      color: color,
    );
  }
  
  static TextStyle bodySmall(BuildContext context, {Color? color}) {
    return getResponsiveTextStyle(
      context,
      baseFontSize: 12,
      color: color,
    );
  }
  
  static TextStyle caption(BuildContext context, {Color? color}) {
    return getResponsiveTextStyle(
      context,
      baseFontSize: 10,
      color: color,
    );
  }
  
  /// Button text style that's always readable
  static TextStyle button(BuildContext context, {Color? color}) {
    return getResponsiveTextStyle(
      context,
      baseFontSize: 16,
      fontWeight: FontWeight.w600,
      color: color,
    );
  }
}

/// Extension to make it easier to use responsive text in widgets
extension ResponsiveTextExtension on Text {
  /// Convert regular Text widget to responsive Text widget
  Text makeResponsive(BuildContext context) {
    final originalStyle = style ?? const TextStyle();
    final baseFontSize = originalStyle.fontSize ?? 14.0;
    
    return Text(
      data ?? '',
      style: ResponsiveText.getResponsiveTextStyle(
        context,
        baseFontSize: baseFontSize,
        fontWeight: originalStyle.fontWeight,
        color: originalStyle.color,
        letterSpacing: originalStyle.letterSpacing,
        height: originalStyle.height,
      ),
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines,
      textScaler: TextScaler.linear(1.0), // We handle scaling ourselves
    );
  }
}

/// Responsive padding utility
class ResponsivePadding {
  /// Get padding that scales with screen size
  static EdgeInsets all(BuildContext context, double basePadding) {
    final scaleFactor = ResponsiveText.getTextScaleFactor(context);
    final adjustedPadding = basePadding * scaleFactor;
    return EdgeInsets.all(adjustedPadding);
  }
  
  /// Get symmetric padding that scales with screen size
  static EdgeInsets symmetric(BuildContext context, {double horizontal = 0, double vertical = 0}) {
    final scaleFactor = ResponsiveText.getTextScaleFactor(context);
    return EdgeInsets.symmetric(
      horizontal: horizontal * scaleFactor,
      vertical: vertical * scaleFactor,
    );
  }
  
  /// Get directional padding that scales with screen size
  static EdgeInsets only(BuildContext context, {double left = 0, double top = 0, double right = 0, double bottom = 0}) {
    final scaleFactor = ResponsiveText.getTextScaleFactor(context);
    return EdgeInsets.only(
      left: left * scaleFactor,
      top: top * scaleFactor,
      right: right * scaleFactor,
      bottom: bottom * scaleFactor,
    );
  }
}
