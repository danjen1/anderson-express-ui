import 'package:flutter/material.dart';
import 'package:cleaning_demo/utils/status_badge_config.dart';

/// Column configuration for a sortable table
class TableColumnConfig {
  final String label;
  final bool sortable;
  final int index;

  const TableColumnConfig({
    required this.label,
    required this.index,
    this.sortable = true,
  });
}

/// Generic sortable DataTable for entity lists
class SortableEntityTable<T> extends StatelessWidget {
  final List<T> items;
  final List<TableColumnConfig> columns;
  final int? sortColumnIndex;
  final bool sortAscending;
  final void Function(int columnIndex, bool ascending) onSort;
  final List<DataCell> Function(BuildContext context, T item) buildCells;
  final bool hasPhoto;
  final String? Function(T item)? getPhotoUrl;
  final String Function(T item)? getInitial;
  final String Function(T item)? getStatus;

  const SortableEntityTable({
    super.key,
    required this.items,
    required this.columns,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onSort,
    required this.buildCells,
    this.hasPhoto = false,
    this.getPhotoUrl,
    this.getInitial,
    this.getStatus,
  });

  @override
  Widget build(BuildContext context) {
    return DataTable(
      headingTextStyle: const TextStyle(fontWeight: FontWeight.w700),
      columnSpacing: 32,
      sortColumnIndex: sortColumnIndex,
      sortAscending: sortAscending,
      columns: columns.map((col) {
        if (col.sortable) {
          return DataColumn(
            label: Text(col.label),
            onSort: onSort,
          );
        } else {
          return DataColumn(label: Text(col.label));
        }
      }).toList(),
      rows: items.map((item) => DataRow(
        cells: buildCells(context, item),
      )).toList(),
    );
  }

  /// Helper to build status badge cell
  static DataCell buildStatusCell(String status, BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DataCell(
      getStatusBadge(status, isDark: dark).build(),
    );
  }

  /// Helper to build photo/avatar cell
  static DataCell buildPhotoCell({
    required BuildContext context,
    String? photoUrl,
    required String initial,
  }) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return DataCell(
        CircleAvatar(
          radius: 16,
          backgroundImage: NetworkImage(photoUrl),
        ),
      );
    }
    return DataCell(
      CircleAvatar(
        radius: 16,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          initial.isNotEmpty ? initial[0].toUpperCase() : '?',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Helper to build details button cell
  static DataCell buildDetailsCell({
    required VoidCallback onPressed,
  }) {
    return DataCell(
      IconButton(
        icon: const Icon(Icons.visibility_outlined, size: 20),
        tooltip: 'View Details',
        onPressed: onPressed,
      ),
    );
  }
}
