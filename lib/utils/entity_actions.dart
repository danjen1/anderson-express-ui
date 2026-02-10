import 'package:flutter/material.dart';
import '../services/app_env.dart';
import '../theme/crud_modal_theme.dart';
import '../utils/error_text.dart';
import 'dialog_utils.dart';

/// Reusable entity delete handler with confirmation, demo mode, and error handling.
///
/// Handles the complete delete flow:
/// 1. Shows confirmation dialog
/// 2. Checks demo mode and shows appropriate message
/// 3. Executes delete operation
/// 4. Refreshes data on success
/// 5. Shows success/error messages
///
/// Example:
/// ```dart
/// Future<void> _deleteEmployee(Employee emp) => deleteEntityWithConfirmation(
///   context: context,
///   itemType: 'employee',
///   itemName: '${emp.employeeNumber} ${emp.name}',
///   onDelete: () => _api.deleteEmployee(emp.id, bearerToken: _token),
///   onSuccess: _loadAdminData,
///   successMessage: '${emp.employeeNumber} ${emp.name} deleted successfully.',
/// );
/// ```
Future<void> deleteEntityWithConfirmation({
  required BuildContext context,
  required String itemType,
  required String itemName,
  required Future<void> Function() onDelete,
  required VoidCallback onSuccess,
  required String successMessage,
}) async {
  // Show confirmation dialog
  final confirmed = await showDeleteConfirmationDialog(
    context,
    itemType: itemType,
    itemName: itemName,
  );

  if (!confirmed) return;

  // Handle demo mode
  if (AppEnv.isDemoMode) {
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (dialogContext) => Theme(
        data: buildCrudModalTheme(context),
        child: AlertDialog(
          title: Text('Demo ${itemType.substring(0, 1).toUpperCase()}${itemType.substring(1)} Deleted'),
          content: Text(
            '$itemType "$itemName" was removed in preview mode. No actual changes were made.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
    return;
  }

  // Execute delete operation
  try {
    await onDelete();
    onSuccess();
    if (!context.mounted) return;
    showSuccessSnackBar(context, successMessage);
  } catch (error) {
    if (!context.mounted) return;
    showErrorSnackBar(context, userFacingError(error));
  }
}
