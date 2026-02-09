import 'package:flutter/services.dart';

/// Formats phone numbers as (555) 555-5555
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    
    // Remove all non-digits
    final digitsOnly = text.replaceAll(RegExp(r'\D'), '');
    
    // Limit to 10 digits
    final limitedDigits = digitsOnly.substring(
      0,
      digitsOnly.length > 10 ? 10 : digitsOnly.length,
    );
    
    // Format based on length
    String formatted;
    if (limitedDigits.isEmpty) {
      formatted = '';
    } else if (limitedDigits.length <= 3) {
      formatted = '($limitedDigits';
    } else if (limitedDigits.length <= 6) {
      formatted = '(${limitedDigits.substring(0, 3)}) ${limitedDigits.substring(3)}';
    } else {
      formatted = '(${limitedDigits.substring(0, 3)}) ${limitedDigits.substring(3, 6)}-${limitedDigits.substring(6)}';
    }
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Cleans a formatted phone number to digits only
String cleanPhoneNumber(String formatted) {
  return formatted.replaceAll(RegExp(r'\D'), '');
}

/// Validates a phone number has exactly 10 digits
bool isValidPhoneNumber(String phone) {
  final digits = cleanPhoneNumber(phone);
  return digits.length == 10;
}

/// Formats a clean phone number string to (555) 555-5555
String formatPhoneNumber(String digits) {
  final cleaned = cleanPhoneNumber(digits);
  if (cleaned.isEmpty) return '';
  if (cleaned.length <= 3) return '($cleaned';
  if (cleaned.length <= 6) {
    return '(${cleaned.substring(0, 3)}) ${cleaned.substring(3)}';
  }
  return '(${cleaned.substring(0, 3)}) ${cleaned.substring(3, 6)}-${cleaned.substring(6)}';
}
