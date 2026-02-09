import 'package:flutter/material.dart';
import '../../../models/job.dart';
import '../../../utils/date_format.dart';

class JobsSection extends StatelessWidget {
  const JobsSection({
    super.key,
    required this.filteredJobs,
    required this.jobDateRange,
    required this.onDateRangeChanged,
    required this.onShowCreateJobDialog,
    required this.onShowEditJobDialog,
    required this.onDeleteJob,
    required this.buildSectionHeader,
    required this.buildCenteredSection,
    required this.buildTableColumn,
    required this.buildRowActionButton,
    required this.isOverdue,
  });

  final List<Job> filteredJobs;
  final DateTimeRange jobDateRange;
  final Function(DateTimeRange) onDateRangeChanged;
  final VoidCallback onShowCreateJobDialog;
  final Function(Job) onShowEditJobDialog;
  final Function(Job) onDeleteJob;
  final Widget Function(String title, String subtitle) buildSectionHeader;
  final Widget Function(Widget child) buildCenteredSection;
  final DataColumn Function({
    required String label,
    bool numeric,
    double? minWidth,
  }) buildTableColumn;
  final Widget Function({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) buildRowActionButton;
  final bool Function(Job) isOverdue;

  String _minutesLabel(int? value) {
    if (value == null || value < 0) return '—';
    final hours = value ~/ 60;
    final minutes = value % 60;
    if (hours == 0) return '${minutes}m';
    return '${hours}h ${minutes}m';
  }

  ({String label, Color bg, Color fg, Color border}) _statusBadge(
    BuildContext context,
    Job job,
  ) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final status = job.status.trim().toLowerCase();
    if (isOverdue(job)) {
      return (
        label: 'O',
        bg: dark ? const Color(0xFF4A2D35) : const Color(0xFFFFE5EC),
        fg: dark ? const Color(0xFFFFC1CC) : const Color(0xFFE63721),
        border: dark ? const Color(0xFFB85B74) : const Color(0xFFE63721),
      );
    }
    return switch (status) {
      'assigned' => (
        label: 'A',
        bg: dark ? const Color(0xFF5A5530) : const Color(0xFFFFF7C5),
        fg: dark ? const Color(0xFFF7EFAE) : const Color(0xFF7A6F00),
        border: dark ? const Color(0xFFCADA56) : const Color(0xFFB3A846),
      ),
      'pending' => (
        label: 'P',
        bg: dark ? const Color(0xFF4B3D2A) : const Color(0xFFFFE3CC),
        fg: dark ? const Color(0xFFFFD3AD) : const Color(0xFF8A4E17),
        border: dark ? const Color(0xFFB17945) : const Color(0xFFEE7E32),
      ),
      'in_progress' || 'in progress' || 'in-progress' => (
        label: 'I',
        bg: dark ? const Color(0xFF3D3550) : const Color(0xFFE8DDF7),
        fg: dark ? const Color(0xFFE4E4E4) : const Color(0xFF442E6F),
        border: dark ? const Color(0xFF8C74B2) : const Color(0xFF7A56A5),
      ),
      'completed' => (
        label: 'C',
        bg: dark ? const Color(0xFF2C4A40) : const Color(0xFFDBF3E8),
        fg: dark ? const Color(0xFFE4E4E4) : const Color(0xFF1E6A4F),
        border: dark ? const Color(0xFF6DB598) : const Color(0xFF49A07D),
      ),
      _ => (
        label: '?',
        bg: dark ? const Color(0xFF41424B) : const Color(0xFFE9EEF2),
        fg: dark ? const Color(0xFFE4E4E4) : const Color(0xFF41588E),
        border: dark ? const Color(0xFF7A7E8C) : const Color(0xFFBEDCE4),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final rangeStart = DateTime(
      jobDateRange.start.year,
      jobDateRange.start.month,
      jobDateRange.start.day,
    );
    final rangeEnd = DateTime(
      jobDateRange.end.year,
      jobDateRange.end.month,
      jobDateRange.end.day,
      23,
      59,
      59,
    );
    final rows = filteredJobs.where((job) {
      final scheduled = parseFlexibleDate(job.scheduledDate);
      if (scheduled == null) return true;
      return !scheduled.isBefore(rangeStart) && !scheduled.isAfter(rangeEnd);
    }).toList();
    rows.sort((a, b) {
      final aDate = parseFlexibleDate(a.scheduledDate);
      final bDate = parseFlexibleDate(b.scheduledDate);
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });

    return ListView(
      children: [
        buildSectionHeader('Jobs', 'Manage all cleaning jobs.'),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Range: ${formatDateMdy(jobDateRange.start.toIso8601String())} – ${formatDateMdy(jobDateRange.end.toIso8601String())}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2050),
                          initialDateRange: jobDateRange,
                        );
                        if (picked != null) {
                          onDateRangeChanged(picked);
                        }
                      },
                      icon: const Icon(Icons.date_range),
                      label: const Text('Change Range'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: onShowCreateJobDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('New Job'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (rows.isEmpty)
                  buildCenteredSection(
                    Text(
                      'No jobs in selected date range.',
                      style: TextStyle(color: Theme.of(context).hintColor),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 700),
                        child: DataTable(
                          headingTextStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                          columns: [
                            buildTableColumn(label: 'S', minWidth: 28),
                            buildTableColumn(label: 'Job #'),
                            buildTableColumn(label: 'Client'),
                            buildTableColumn(label: 'Location'),
                            buildTableColumn(label: 'Date'),
                            buildTableColumn(label: 'Cleaner'),
                            buildTableColumn(label: 'Est.', numeric: true),
                            buildTableColumn(label: 'Act.', numeric: true),
                            buildTableColumn(label: 'Status'),
                            buildTableColumn(label: 'Actions'),
                          ],
                          rows: rows
                              .map(
                                (job) {
                                  final badge = _statusBadge(context, job);
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Container(
                                          width: 18,
                                          height: 18,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: badge.bg,
                                            border: Border.all(
                                              color: badge.border,
                                              width: 1.5,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(3),
                                          ),
                                          child: Text(
                                            badge.label,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: badge.fg,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(Text(job.jobNumber)),
                                      DataCell(
                                        Text(job.clientName ?? 'N/A'),
                                      ),
                                      DataCell(
                                        Text(job.clientName ?? 'N/A'),
                                      ),
                                      DataCell(
                                        Text(formatDateMdy(job.scheduledDate)),
                                      ),
                                      DataCell(
                                        Text('Unassigned'),
                                      ),
                                      DataCell(
                                        Text(_minutesLabel(job.estimatedDurationMinutes)),
                                      ),
                                      DataCell(
                                        Text(_minutesLabel(job.actualDurationMinutes)),
                                      ),
                                      DataCell(
                                        Text(
                                          job.status,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            buildRowActionButton(
                                              icon: Icons.edit,
                                              tooltip: 'Edit',
                                              onPressed: () =>
                                                  onShowEditJobDialog(job),
                                            ),
                                            const SizedBox(width: 10),
                                            buildRowActionButton(
                                              icon: Icons.delete,
                                              tooltip: 'Delete',
                                              onPressed: () =>
                                                  onDeleteJob(job),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
