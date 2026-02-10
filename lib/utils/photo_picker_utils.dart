import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/crud_modal_theme.dart';

/// Shows a photo picker dialog and returns the selected photo as a data URL.
/// 
/// Returns null if the user cancels or if an error occurs.
/// 
/// Example:
/// ```dart
/// final photoDataUrl = await showPhotoPickerDialog(
///   context,
///   title: 'Update Profile Photo',
///   message: 'Select a new photo for your profile.',
/// );
/// if (photoDataUrl != null) {
///   // Upload the photo
/// }
/// ```
Future<String?> showPhotoPickerDialog(
  BuildContext context, {
  String title = 'Update Photo',
  String message = 'Select a new photo.',
  int maxSizeKB = 500,
}) async {
  // Show confirmation dialog
  final proceed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => Theme(
      data: buildCrudModalTheme(context),
      child: AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Choose Photo'),
          ),
        ],
      ),
    ),
  );
  
  if (proceed != true) return null;

  // Pick file
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    withData: true,
  );
  
  if (result == null || result.files.isEmpty) return null;
  
  final file = result.files.first;
  final bytes = file.bytes;
  
  if (bytes == null || bytes.isEmpty) return null;
  
  // Check file size
  if (bytes.length > maxSizeKB * 1024) {
    if (!context.mounted) return null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Image must be under ${maxSizeKB}KB. Please choose a smaller file.',
        ),
        backgroundColor: Colors.red[700],
      ),
    );
    return null;
  }

  // Convert to data URL
  final ext = (file.extension ?? '').toLowerCase();
  final mime = switch (ext) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'image/jpeg',
  };
  
  return 'data:$mime;base64,${base64Encode(bytes)}';
}
