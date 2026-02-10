/// Reusable sort comparator functions for common sorting patterns

/// Generic status comparator with priority ordering
///
/// Compares two status strings based on a priority list.
/// Items in the priority list come first in ascending order.
/// Items not in the list are sorted alphabetically after priority items.
///
/// Example:
/// ```dart
/// // Employees: invited → active → inactive → resigned → deleted
/// comparison = compareByStatusPriority(
///   a.status,
///   b.status,
///   StatusPriority.employee,
/// );
/// ```
int compareByStatusPriority(
  String statusA,
  String statusB,
  List<String> priorityOrder,
) {
  final aLower = statusA.trim().toLowerCase();
  final bLower = statusB.trim().toLowerCase();

  final aIndex = priorityOrder.indexOf(aLower);
  final bIndex = priorityOrder.indexOf(bLower);

  // Both in priority list - compare by index
  if (aIndex != -1 && bIndex != -1) {
    return aIndex.compareTo(bIndex);
  }

  // Only A in priority list - A comes first
  if (aIndex != -1 && bIndex == -1) {
    return -1;
  }

  // Only B in priority list - B comes first
  if (aIndex == -1 && bIndex != -1) {
    return 1;
  }

  // Neither in priority list - alphabetical
  return aLower.compareTo(bLower);
}

/// Case-insensitive string comparator
///
/// Compares two strings case-insensitively, treating null as empty string.
///
/// Example:
/// ```dart
/// comparison = compareStringsCaseInsensitive(a.name, b.name);
/// ```
int compareStringsCaseInsensitive(String? a, String? b) {
  return (a ?? '').toLowerCase().compareTo((b ?? '').toLowerCase());
}

/// Case-insensitive nullable string comparator
///
/// Null values are sorted to the end (after all non-null values).
///
/// Example:
/// ```dart
/// comparison = compareNullableStrings(a.email, b.email);
/// ```
int compareNullableStrings(String? a, String? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1; // Nulls to end
  if (b == null) return -1; // Nulls to end
  return a.toLowerCase().compareTo(b.toLowerCase());
}

/// Predefined priority orders for common entity types
class StatusPriority {
  /// Employee status priority: invited → active → inactive → resigned → deleted
  static const employee = [
    'invited',
    'active',
    'inactive',
    'resigned',
    'deleted',
  ];

  /// Client status priority: invited → active → inactive → deleted
  static const client = [
    'invited',
    'active',
    'inactive',
    'deleted',
  ];

  /// Location status priority: active → inactive → deleted
  static const location = [
    'active',
    'inactive',
    'deleted',
  ];

  /// Job status priority: pending → assigned → in_progress → completed → cancelled
  static const job = [
    'pending',
    'assigned',
    'in_progress',
    'completed',
    'cancelled',
  ];
}
