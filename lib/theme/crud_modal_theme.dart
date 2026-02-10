import 'package:flutter/material.dart';

import 'app_colors.dart';

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
      backgroundColor: dark ? AppColors.darkBackground : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: dark ? AppColors.mediumGray : AppColors.lightBlue,
        ),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: WidgetStateProperty.all(
          dark ? AppColors.darkerBackground : Colors.white,
        ),
        surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: dark ? const Color(0xFF657184) : AppColors.paleBlue,
            ),
          ),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? AppColors.darkerBackground : AppColors.veryLightBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: dark ? const Color(0xFF657184) : AppColors.paleBlue,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: dark ? const Color(0xFF657184) : AppColors.paleBlue,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: dark ? AppColors.primaryPurple : AppColors.accentTeal,
          width: 1.4,
        ),
      ),
      labelStyle: TextStyle(
        color: dark ? AppColors.lightBackground : AppColors.primaryDarkPurple,
      ),
      hintStyle: TextStyle(
        color: dark ? const Color(0xFFB8BCC4) : const Color(0xFF6A6A6A),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: dark
            ? AppColors.accentCyan
            : AppColors.accentTeal,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: dark
            ? AppColors.accentCyan
            : AppColors.accentTeal,
        side: BorderSide(
          color: dark ? const Color(0xFF657184) : AppColors.paleBlue,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: dark
            ? AppColors.primaryPurple
            : AppColors.primaryDarkPurple,
        foregroundColor: dark ? AppColors.darkerBackground : Colors.white,
      ),
    ),
  );
}

/// Returns the appropriate title color for CRUD modals based on theme brightness.
Color crudModalTitleColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? AppColors.primaryPurple
      : AppColors.primaryDarkPurple;
}

/// Returns the appropriate color for required field indicators in CRUD modals.
Color crudModalRequiredColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? AppColors.lightPink
      : AppColors.primaryDarkPurple;
}
