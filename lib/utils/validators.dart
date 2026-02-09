/// Shared form validation utilities for the Anderson Express application.
///
/// This file provides consistent validation logic across all forms
/// to ensure data integrity and improve security.
library;

/// Common form field validators
class Validators {
  /// Validates that a field is not empty
  ///
  /// [fieldName] is used in the error message (e.g., "Email", "Phone number")
  /// Returns null if valid, error message if invalid
  static String? required(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validates email address format
  ///
  /// Checks for:
  /// - At least one character before @
  /// - @ symbol
  /// - Domain name with at least one dot
  /// - TLD with at least 2 characters
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  /// Validates phone number format
  ///
  /// Accepts formats like:
  /// - (555) 123-4567
  /// - 555-123-4567
  /// - 555.123.4567
  /// - 5551234567
  /// - +1 555 123 4567
  static String? phoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Phone is often optional
    }

    // Remove all non-digit characters for validation
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');

    // US phone numbers should have 10 or 11 digits (with country code)
    if (digitsOnly.length < 10 || digitsOnly.length > 11) {
      return 'Please enter a valid phone number';
    }

    return null;
  }

  /// Validates phone number format (required version)
  static String? phoneNumberRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }

    return phoneNumber(value);
  }

  /// Validates minimum length
  ///
  /// [minLength] is the minimum number of characters required
  /// [fieldName] is used in the error message
  static String? minLength(String? value, int minLength, {String fieldName = 'This field'}) {
    if (value == null || value.isEmpty) {
      return null; // Use required() validator for empty check
    }

    if (value.length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }

    return null;
  }

  /// Validates maximum length
  ///
  /// [maxLength] is the maximum number of characters allowed
  /// [fieldName] is used in the error message
  static String? maxLength(String? value, int maxLength, {String fieldName = 'This field'}) {
    if (value == null || value.isEmpty) {
      return null; // Use required() validator for empty check
    }

    if (value.length > maxLength) {
      return '$fieldName must be at most $maxLength characters';
    }

    return null;
  }

  /// Validates numeric input
  ///
  /// Checks if the value can be parsed as a number
  static String? numeric(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return null; // Use required() validator for empty check
    }

    if (double.tryParse(value.trim()) == null) {
      return '$fieldName must be a valid number';
    }

    return null;
  }

  /// Validates numeric input (required version)
  static String? numericRequired(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }

    return numeric(value, fieldName: fieldName);
  }

  /// Combines multiple validators
  ///
  /// Returns the first error found, or null if all validations pass
  /// 
  /// Example:
  /// ```dart
  /// validator: Validators.combine([
  ///   (v) => Validators.required(v, fieldName: 'Email'),
  ///   Validators.email,
  /// ])
  /// ```
  static String? Function(String?) combine(List<String? Function(String?)> validators) {
    return (String? value) {
      for (final validator in validators) {
        final error = validator(value);
        if (error != null) {
          return error;
        }
      }
      return null;
    };
  }
}
