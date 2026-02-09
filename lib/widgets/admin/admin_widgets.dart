import 'package:flutter/material.dart';

/// Section header widget used across admin sections
class AdminSectionHeader extends StatelessWidget {
  const AdminSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Theme.of(context).hintColor)),
        ],
      ),
    );
  }
}

/// Metric tile widget for dashboard stats
class AdminMetricTile extends StatelessWidget {
  const AdminMetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.bg,
    required this.fg,
    this.icon,
  });

  final String label;
  final String value;
  final Color bg;
  final Color fg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.w700, color: fg),
          ),
          Text(value, style: TextStyle(color: fg)),
        ],
      ),
    );
  }
}

/// Centers and constrains section content
class AdminCenteredSection extends StatelessWidget {
  const AdminCenteredSection({
    super.key,
    required this.child,
    this.maxWidth = 1240,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Compact action button for table rows
class AdminRowActionButton extends StatelessWidget {
  const AdminRowActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      splashRadius: 14,
      iconSize: 18,
      onPressed: onPressed,
    );
  }
}

/// Standard table header style
class AdminTableHeaderStyle {
  static const TextStyle style = TextStyle(fontWeight: FontWeight.w800);

  static DataColumn column(String label) {
    return DataColumn(label: Text(label, style: style));
  }
}

/// Status badge configuration
class StatusBadgeConfig {
  const StatusBadgeConfig({
    required this.label,
    required this.bg,
    required this.fg,
    required this.border,
  });

  final String label;
  final Color bg;
  final Color fg;
  final Color border;
}

/// Get status badge configuration for common statuses
StatusBadgeConfig getStatusBadgeConfig(String status) {
  final normalized = status.trim().toLowerCase();
  switch (normalized) {
    case 'active':
      return const StatusBadgeConfig(
        label: 'A',
        bg: Color(0xFFE7F4ED),
        fg: Color(0xFF1F6A43),
        border: Color(0xFF49A07D),
      );
    case 'invited':
      return const StatusBadgeConfig(
        label: 'V',
        bg: Color(0xFFFFF4E7),
        fg: Color(0xFF9B4B12),
        border: Color(0xFFEE7E32),
      );
    case 'deleted':
      return const StatusBadgeConfig(
        label: 'D',
        bg: Color(0xFFFBE7EE),
        fg: Color(0xFFE63721),
        border: Color(0xFFE63721),
      );
    default:
      return StatusBadgeConfig(
        label: normalized.isEmpty ? '?' : normalized[0].toUpperCase(),
        bg: const Color(0xFFEAF0F5),
        fg: const Color(0xFF41588E),
        border: const Color(0xFF8AA4C7),
      );
  }
}
