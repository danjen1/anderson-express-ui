import 'package:flutter/material.dart';

/// Status badge color configuration
class StatusBadgeColors {
  final Color bg;
  final Color fg;
  final Color border;

  const StatusBadgeColors({
    required this.bg,
    required this.fg,
    required this.border,
  });
}

/// A circular badge widget for displaying status with theme-aware colors.
/// 
/// Supports common statuses like 'open', 'pending', 'completed', 'active', etc.
/// and provides appropriate colors for light and dark modes.
/// 
/// Example:
/// ```dart
/// StatusBadge(status: 'active')
/// StatusBadge(status: 'completed', isDark: true)
/// StatusBadge.custom(label: 'Custom', colors: StatusBadgeColors(...))
/// ```
class StatusBadge extends StatelessWidget {
  final String status;
  final bool isDark;
  final StatusBadgeColors? customColors;

  const StatusBadge({
    super.key,
    required this.status,
    this.isDark = false,
    this.customColors,
  });

  /// Creates a status badge with custom colors
  const StatusBadge.custom({
    super.key,
    required String label,
    required StatusBadgeColors colors,
    this.isDark = false,
  })  : status = label,
        customColors = colors;

  @override
  Widget build(BuildContext context) {
    final colors = customColors ?? _getColorsForStatus(status, isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: colors.fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Get appropriate colors for common status values
  static StatusBadgeColors _getColorsForStatus(String status, bool isDark) {
    final normalizedStatus = status.toLowerCase().trim();

    // Job/Request statuses
    if (normalizedStatus == 'completed' || normalizedStatus == 'closed') {
      return const StatusBadgeColors(
        bg: Color(0xFFE7F4ED),
        fg: Color(0xFF1F6A43),
        border: Color(0xFF49A07D),
      );
    }
    if (normalizedStatus == 'pending' || normalizedStatus == 'open') {
      return const StatusBadgeColors(
        bg: Color(0xFFFFF4E7),
        fg: Color(0xFF9B4B12),
        border: Color(0xFFEE7E32),
      );
    }
    if (normalizedStatus == 'overdue' || normalizedStatus == 'cancelled') {
      return const StatusBadgeColors(
        bg: Color(0xFFFBE7EE),
        fg: Color(0xFFE63721),
        border: Color(0xFFE63721),
      );
    }
    if (normalizedStatus == 'assigned' || normalizedStatus == 'scheduled') {
      return const StatusBadgeColors(
        bg: Color(0xFFEAF0F5),
        fg: Color(0xFF41588E),
        border: Color(0xFF8AA4C7),
      );
    }

    // Cleaning request statuses (dark mode support)
    if (normalizedStatus == 'reviewed') {
      return StatusBadgeColors(
        bg: isDark ? const Color(0xFF4A2D35) : const Color(0xFFFFE5EC),
        fg: isDark ? const Color(0xFFFFC1CC) : const Color(0xFFE63721),
        border: isDark ? const Color(0xFFB85B74) : const Color(0xFFE63721),
      );
    }

    // Employee/Client statuses
    if (normalizedStatus == 'active') {
      return StatusBadgeColors(
        bg: isDark ? const Color(0xFF2C4A40) : const Color(0xFFDBF3E8),
        fg: isDark ? const Color(0xFFE4E4E4) : const Color(0xFF1E6A4F),
        border: isDark ? const Color(0xFF6DB598) : const Color(0xFF49A07D),
      );
    }
    if (normalizedStatus == 'inactive' || normalizedStatus == 'deleted') {
      return StatusBadgeColors(
        bg: isDark ? const Color(0xFF41424B) : const Color(0xFFE9EEF2),
        fg: isDark ? const Color(0xFFE4E4E4) : const Color(0xFF41588E),
        border: isDark ? const Color(0xFF7A7E8C) : const Color(0xFFBEDCE4),
      );
    }
    if (normalizedStatus == 'invited') {
      return StatusBadgeColors(
        bg: isDark ? const Color(0xFF5A5530) : const Color(0xFFFFF7C5),
        fg: isDark ? const Color(0xFFF7EFAE) : const Color(0xFF7A6F00),
        border: isDark ? const Color(0xFFCADA56) : const Color(0xFFB3A846),
      );
    }
    if (normalizedStatus == 'resigned') {
      return StatusBadgeColors(
        bg: isDark ? const Color(0xFF4B3D2A) : const Color(0xFFFFE3CC),
        fg: isDark ? const Color(0xFFFFD3AD) : const Color(0xFF8A4E17),
        border: isDark ? const Color(0xFFB17945) : const Color(0xFFEE7E32),
      );
    }
    if (normalizedStatus == 'in_progress' || normalizedStatus == 'in progress') {
      return StatusBadgeColors(
        bg: isDark ? const Color(0xFF3D3550) : const Color(0xFFE8DDF7),
        fg: isDark ? const Color(0xFFE4E4E4) : const Color(0xFF442E6F),
        border: isDark ? const Color(0xFF8C74B2) : const Color(0xFF7A56A5),
      );
    }

    // Default/unknown status
    return StatusBadgeColors(
      bg: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF0F0F0),
      fg: isDark ? const Color(0xFFE4E4E4) : const Color(0xFF666666),
      border: isDark ? const Color(0xFF555555) : const Color(0xFFCCCCCC),
    );
  }
}
