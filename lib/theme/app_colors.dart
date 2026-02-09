import 'package:flutter/material.dart';

/// Centralized color palette for the Anderson Express application.
///
/// This file defines all colors used throughout the app to ensure
/// consistency and make it easy to update the brand colors.
class AppColors {
  // ============================================================================
  // PRIMARY BRAND COLORS
  // ============================================================================

  /// Primary purple color (dark mode primary)
  static const Color primaryPurple = Color(0xFFB39CD0);

  /// Primary dark purple (light mode primary)
  static const Color primaryDarkPurple = Color(0xFF442E6F);

  /// Accent cyan (dark mode accent)
  static const Color accentCyan = Color(0xFFA8DADC);

  /// Accent teal (light mode accent)
  static const Color accentTeal = Color(0xFF296273);

  /// Light blue accent
  static const Color lightBlue = Color(0xFFA8D6F7);

  /// Pale blue
  static const Color paleBlue = Color(0xFFBEDCE4);

  // ============================================================================
  // ANDERSON EXPRESS BRAND COLORS
  // ============================================================================

  /// Anderson Express Orange (primary brand color)
  static const Color andersonOrange = Color(0xFFEE7E32);

  /// Anderson Express Red
  static const Color andersonRed = Color(0xFFE63721);

  /// Anderson Express Navy
  static const Color andersonNavy = Color(0xFF41588E);

  // ============================================================================
  // BACKGROUND COLORS
  // ============================================================================

  /// Dark background (dark mode)
  static const Color darkBackground = Color(0xFF2C2C2C);

  /// Darker background variant
  static const Color darkerBackground = Color(0xFF1F1F1F);

  /// Dark gray background
  static const Color darkGray = Color(0xFF3A3A3A);

  /// Medium gray
  static const Color mediumGray = Color(0xFF4A525F);

  /// Dark slate
  static const Color darkSlate = Color(0xFF3B4250);

  /// Light background (light mode)
  static const Color lightBackground = Color(0xFFE4E4E4);

  /// Very light background
  static const Color veryLightBackground = Color(0xFFF7FCFE);

  /// Pale background
  static const Color paleBackground = Color(0xFFE7F3FB);

  /// Cream background
  static const Color creamBackground = Color(0xFFFFF4E7);

  // ============================================================================
  // STATUS COLORS
  // ============================================================================

  /// Success green
  static const Color success = Color(0xFF49A07D);

  /// Error red (same as Anderson red)
  static const Color error = andersonRed;

  /// Warning orange (same as Anderson orange)
  static const Color warning = andersonOrange;

  /// Info blue (same as light blue)
  static const Color info = lightBlue;

  // ============================================================================
  // SPECIAL COLORS
  // ============================================================================

  /// Light pink
  static const Color lightPink = Color(0xFFFFC1CC);

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Returns the appropriate primary color based on theme brightness
  static Color primary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? primaryPurple
        : primaryDarkPurple;
  }

  /// Returns the appropriate accent color based on theme brightness
  static Color accent(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? accentCyan
        : accentTeal;
  }

  /// Returns the appropriate background color based on theme brightness
  static Color background(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBackground
        : Colors.white;
  }

  /// Returns the appropriate card color based on theme brightness
  static Color card(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkGray
        : lightBackground;
  }
}
