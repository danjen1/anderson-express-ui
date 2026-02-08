DateTime? parseFlexibleDate(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  try {
    return DateTime.parse(trimmed).toLocal();
  } catch (_) {
    final parts = trimmed.split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) {
        return DateTime(y, m, d);
      }
    }
    return null;
  }
}

String formatDateMdy(String raw) {
  final parsed = parseFlexibleDate(raw);
  if (parsed == null) return raw;
  return '${parsed.month}-${parsed.day}-${parsed.year}';
}

