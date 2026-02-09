import 'package:flutter/material.dart';

/// Shows a confirmation dialog for delete operations.
/// 
/// Returns `true` if the user confirms the deletion, `false` otherwise.
/// 
/// Example:
/// ```dart
/// final confirmed = await showDeleteConfirmationDialog(
///   context,
///   itemType: 'employee',
///   itemName: 'John Doe',
/// );
/// if (confirmed) {
///   // Perform deletion
/// }
/// ```
Future<bool> showDeleteConfirmationDialog(
  BuildContext context, {
  required String itemType,
  required String itemName,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete $itemType?'),
      content: Text(
        'Are you sure you want to delete $itemName? This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return result == true;
}

/// Shows a simple information dialog with an OK button.
/// 
/// Example:
/// ```dart
/// await showInfoDialog(
///   context,
///   title: 'Success',
///   message: 'Employee created successfully.',
/// );
/// ```
Future<void> showInfoDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// Shows an error dialog with details.
/// 
/// Example:
/// ```dart
/// await showErrorDialog(
///   context,
///   title: 'Error',
///   message: 'Failed to save employee: ${error.toString()}',
/// );
/// ```
Future<void> showErrorDialog(
  BuildContext context, {
  String title = 'Error',
  required String message,
}) async {
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// Shows a success SnackBar with a green background.
///
/// Example:
/// ```dart
/// showSuccessSnackBar(context, 'Employee created successfully');
/// ```
void showSuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.green[700],
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Shows an error SnackBar with a red background.
///
/// Example:
/// ```dart
/// showErrorSnackBar(context, 'Failed to delete employee: ${error.toString()}');
/// ```
void showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red[700],
      behavior: SnackBarBehavior.floating,
    ),
  );
}
