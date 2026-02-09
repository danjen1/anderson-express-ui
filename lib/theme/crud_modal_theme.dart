import 'package:flutter/material.dart';

/// Builds a consistent theme for CRUD modal dialogs across the application.
/// 
/// This theme provides standardized styling for:
/// - Dialog backgrounds and borders
/// - Input fields (filled, borders, focus states)
/// - Buttons (text, outlined, filled)
/// - Colors adapted for light and dark modes
ThemeData buildCrudModalTheme(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return Theme.of(context).copyWith(
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? const Color(0xFF2C2C2C) : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: dark ? const Color(0xFF4A525F) : const Color(0xFFA8D6F7),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF1F1F1F) : const Color(0xFFF7FCFE),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: dark ? const Color(0xFF657184) : const Color(0xFFBEDCE4),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: dark ? const Color(0xFF657184) : const Color(0xFFBEDCE4),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: dark ? const Color(0xFFB39CD0) : const Color(0xFF296273),
          width: 1.4,
        ),
      ),
      labelStyle: TextStyle(
        color: dark ? const Color(0xFFE4E4E4) : const Color(0xFF442E6F),
      ),
      hintStyle: TextStyle(
        color: dark ? const Color(0xFFB8BCC4) : const Color(0xFF6A6A6A),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: dark
            ? const Color(0xFFA8DADC)
            : const Color(0xFF296273),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: dark
            ? const Color(0xFFA8DADC)
            : const Color(0xFF296273),
        side: BorderSide(
          color: dark ? const Color(0xFF657184) : const Color(0xFFBEDCE4),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: dark
            ? const Color(0xFFB39CD0)
            : const Color(0xFF442E6F),
        foregroundColor: dark ? const Color(0xFF1F1F1F) : Colors.white,
      ),
    ),
  );
}

/// Returns the appropriate title color for CRUD modals based on theme brightness.
Color crudModalTitleColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFB39CD0)
      : const Color(0xFF442E6F);
}

/// Returns the appropriate color for required field indicators in CRUD modals.
Color crudModalRequiredColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFFFC1CC)
      : const Color(0xFF442E6F);
}
