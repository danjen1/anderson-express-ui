import 'package:flutter/material.dart';

/// Utilities for common date range calculations.
class DateRangeUtils {
  /// Returns a DateTimeRange for the current week (Sunday to Saturday).
  static DateTimeRange currentWeekRange() {
    final now = DateTime.now();
    final weekday = now.weekday % 7; // Sunday = 0
    final start = now.subtract(Duration(days: weekday));
    final end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    return DateTimeRange(
      start: DateTime(start.year, start.month, start.day),
      end: DateTime(end.year, end.month, end.day, 23, 59, 59),
    );
  }

  /// Returns a DateTimeRange for the last 30 days.
  static DateTimeRange last30DaysRange() {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));
    return DateTimeRange(
      start: DateTime(start.year, start.month, start.day),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  /// Returns a DateTimeRange for the last 7 days.
  static DateTimeRange last7DaysRange() {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 7));
    return DateTimeRange(
      start: DateTime(start.year, start.month, start.day),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  /// Returns a DateTimeRange for the current month.
  static DateTimeRange currentMonthRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return DateTimeRange(start: start, end: end);
  }

  /// Returns a DateTimeRange for the last month.
  static DateTimeRange lastMonthRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 1, 1);
    final end = DateTime(now.year, now.month, 0, 23, 59, 59);
    return DateTimeRange(start: start, end: end);
  }
}
