String userFacingError(Object error) {
  final raw = error.toString().replaceFirst('Exception: ', '').trim();
  if (raw.isEmpty) return 'Request failed. Please try again.';

  final lowered = raw.toLowerCase();
  if (lowered.contains('http 5')) {
    return 'Server is temporarily unavailable. Please try again.';
  }
  if (lowered.contains('timed out') || lowered.contains('timeout')) {
    return 'Request timed out. Check your connection and try again.';
  }
  if (lowered.contains('socket') || lowered.contains('failed host lookup')) {
    return 'Cannot reach backend service. Verify environment host settings.';
  }
  if (raw.length > 180) {
    return 'Something went wrong. Please retry or contact support.';
  }
  return raw;
}
