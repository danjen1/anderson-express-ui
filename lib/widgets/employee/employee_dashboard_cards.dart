import 'package:flutter/material.dart';

class EmployeeDateRangeCard extends StatelessWidget {
  const EmployeeDateRangeCard({
    super.key,
    required this.dark,
    required this.range,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onResetWeek,
    this.cardColor,
    this.borderColor,
  });

  final bool dark;
  final DateTimeRange range;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback onResetWeek;
  final Color? cardColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        color: cardColor,
        shape: borderColor == null
            ? null
            : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: borderColor!),
              ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.filter_alt_outlined),
              const Text('Range:'),
              OutlinedButton.icon(
                onPressed: onPickStart,
                icon: const Icon(Icons.date_range, size: 16),
                label: Text(
                  '${range.start.month}-${range.start.day}-${range.start.year}',
                ),
              ),
              const Text('to'),
              OutlinedButton.icon(
                onPressed: onPickEnd,
                icon: const Icon(Icons.date_range, size: 16),
                label: Text(
                  '${range.end.month}-${range.end.day}-${range.end.year}',
                ),
              ),
              TextButton(
                onPressed: onResetWeek,
                child: const Text('This week'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmployeeJobDashboardCard extends StatelessWidget {
  const EmployeeJobDashboardCard({
    super.key,
    required this.dark,
    required this.assignedCount,
    required this.assignedHours,
    required this.completedCount,
    required this.completedHours,
    required this.totalDistanceMiles,
    this.cardColor,
    this.borderColor,
    this.titleColor,
  });

  final bool dark;
  final int assignedCount;
  final String assignedHours;
  final int completedCount;
  final String completedHours;
  final String totalDistanceMiles;
  final Color? cardColor;
  final Color? borderColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final assignedBg = dark ? const Color(0xFF3B465D) : const Color(0xFFDCEEFF);
    final completedBg = dark
        ? const Color(0xFF4A4659)
        : const Color(0xFFE0F6EB);
    final distanceBg = dark ? const Color(0xFF5B4432) : const Color(0xFFFFEDD9);

    return SizedBox(
      width: double.infinity,
      child: Card(
        color: cardColor,
        shape: borderColor == null
            ? null
            : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: borderColor!),
              ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Job Dashboard',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.start,
                children: [
                  _metricTile(
                    dark: dark,
                    label: 'Assigned Jobs',
                    value: assignedCount.toString(),
                    icon: Icons.assignment,
                    bg: assignedBg,
                  ),
                  _metricTile(
                    dark: dark,
                    label: 'Hours Scheduled',
                    value: assignedHours,
                    icon: Icons.schedule,
                    bg: assignedBg,
                  ),
                  _metricTile(
                    dark: dark,
                    label: 'Completed Jobs',
                    value: completedCount.toString(),
                    icon: Icons.check_circle_outline,
                    bg: completedBg,
                  ),
                  _metricTile(
                    dark: dark,
                    label: 'Hours Worked',
                    value: completedHours,
                    icon: Icons.timelapse_outlined,
                    bg: completedBg,
                  ),
                  _metricTile(
                    dark: dark,
                    label: 'Total Distance',
                    value: totalDistanceMiles,
                    icon: Icons.route_outlined,
                    bg: distanceBg,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricTile({
    required bool dark,
    required String label,
    required String value,
    required IconData icon,
    required Color bg,
  }) {
    final fg = dark ? const Color(0xFFE4E4E4) : const Color(0xFF442E6F);
    return SizedBox(
      width: 210,
      child: Container(
        constraints: const BoxConstraints(minWidth: 170),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(
              '$label: ',
              style: TextStyle(fontWeight: FontWeight.w700, color: fg),
            ),
            Text(value, style: TextStyle(color: fg)),
          ],
        ),
      ),
    );
  }
}
