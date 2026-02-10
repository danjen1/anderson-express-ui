import 'package:flutter/material.dart';

/// Configuration for status badge appearance
class StatusBadge {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;

  const StatusBadge({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
  });

  /// Builds the visual badge widget
  Widget build() {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Returns status badge configuration based on status string and theme
///
/// Supports statuses:
/// - active, invited, inactive, resigned, deleted (for employees)
/// - active, inactive, deleted (for clients/locations)
/// - pending, in_progress, completed, cancelled (for jobs)
///
/// Example:
/// ```dart
/// final badge = getStatusBadge(employee.status, isDark: isDark);
/// return DataCell(badge.build());
/// ```
StatusBadge getStatusBadge(String status, {required bool isDark}) {
  final statusLower = status.trim().toLowerCase();

  return switch (statusLower) {
    // Active status - green
    'active' => StatusBadge(
      label: 'A',
      backgroundColor: isDark ? const Color(0xFF2C4A40) : const Color(0xFFDBF3E8),
      foregroundColor: isDark ? const Color(0xFFE4E4E4) : const Color(0xFF1E6A4F),
      borderColor: isDark ? const Color(0xFF6DB598) : const Color(0xFF49A07D),
    ),
    
    // Invited status - purple/blue
    'invited' => StatusBadge(
      label: 'I',
      backgroundColor: isDark ? const Color(0xFF3D3D6B) : const Color(0xFFE5E5FF),
      foregroundColor: isDark ? const Color(0xFFE4E4E4) : const Color(0xFF4A4A8A),
      borderColor: isDark ? const Color(0xFF8585CC) : const Color(0xFF6B6BBF),
    ),
    
    // Inactive status - orange
    'inactive' => StatusBadge(
      label: 'X',
      backgroundColor: isDark ? const Color(0xFF5C4A2C) : const Color(0xFFFFF4E5),
      foregroundColor: isDark ? const Color(0xFFE4E4E4) : const Color(0xFF8A6A1E),
      borderColor: isDark ? const Color(0xFFCC9E66) : const Color(0xFFBF9A4A),
    ),
    
    // Resigned status - gray
    'resigned' => StatusBadge(
      label: 'R',
      backgroundColor: isDark ? const Color(0xFF4A4A4A) : const Color(0xFFEEEEEE),
      foregroundColor: isDark ? const Color(0xFFBBBBBB) : const Color(0xFF666666),
      borderColor: isDark ? const Color(0xFF888888) : const Color(0xFF999999),
    ),
    
    // Deleted status - red
    'deleted' => StatusBadge(
      label: 'D',
      backgroundColor: isDark ? const Color(0xFF5C2C2C) : const Color(0xFFFFE5E5),
      foregroundColor: isDark ? const Color(0xFFE4E4E4) : const Color(0xFF8A1E1E),
      borderColor: isDark ? const Color(0xFFCC6666) : const Color(0xFFBF4A4A),
    ),
    
    // Job statuses
    'pending' => StatusBadge(
      label: 'P',
      backgroundColor: isDark ? const Color(0xFF5C4A2C) : const Color(0xFFFFF4E5),
      foregroundColor: isDark ? const Color(0xFFE4E4E4) : const Color(0xFF8A6A1E),
      borderColor: isDark ? const Color(0xFFCC9E66) : const Color(0xFFBF9A4A),
    ),
    
    'assigned' => StatusBadge(
      label: 'A',
      backgroundColor: isDark ? const Color(0xFF3D3D6B) : const Color(0xFFE5E5FF),
      foregroundColor: isDark ? const Color(0xFFE4E4E4) : const Color(0xFF4A4A8A),
      borderColor: isDark ? const Color(0xFF8585CC) : const Color(0xFF6B6BBF),
    ),
    
    'in_progress' => StatusBadge(
      label: 'P',
      backgroundColor: isDark ? const Color(0xFF3D3D6B) : const Color(0xFFE5E5FF),
      foregroundColor: isDark ? const Color(0xFFE4E4E4) : const Color(0xFF4A4A8A),
      borderColor: isDark ? const Color(0xFF8585CC) : const Color(0xFF6B6BBF),
    ),
    
    'completed' => StatusBadge(
      label: 'C',
      backgroundColor: isDark ? const Color(0xFF2C4A40) : const Color(0xFFDBF3E8),
      foregroundColor: isDark ? const Color(0xFFE4E4E4) : const Color(0xFF1E6A4F),
      borderColor: isDark ? const Color(0xFF6DB598) : const Color(0xFF49A07D),
    ),
    
    'cancelled' => StatusBadge(
      label: 'X',
      backgroundColor: isDark ? const Color(0xFF5C2C2C) : const Color(0xFFFFE5E5),
      foregroundColor: isDark ? const Color(0xFFE4E4E4) : const Color(0xFF8A1E1E),
      borderColor: isDark ? const Color(0xFFCC6666) : const Color(0xFFBF4A4A),
    ),
    
    // Overdue status - red (for jobs past due date)
    'overdue' => StatusBadge(
      label: 'O',
      backgroundColor: isDark ? const Color(0xFF4A2D35) : const Color(0xFFFFE5EC),
      foregroundColor: isDark ? const Color(0xFFFFC1CC) : const Color(0xFFE63721),
      borderColor: isDark ? const Color(0xFFB85B74) : const Color(0xFFE63721),
    ),
    
    // Unknown status - fallback
    _ => StatusBadge(
      label: '?',
      backgroundColor: isDark ? const Color(0xFF4A4A4A) : const Color(0xFFCCCCCC),
      foregroundColor: isDark ? const Color(0xFFBBBBBB) : const Color(0xFF666666),
      borderColor: isDark ? const Color(0xFF888888) : const Color(0xFF999999),
    ),
  };
}
