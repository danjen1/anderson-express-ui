import 'package:flutter/material.dart';
import '../../../models/job.dart';
import '../../../models/employee.dart';
import '../../../models/cleaning_request.dart';
import '../../../utils/date_format.dart';

enum CleaningRequestFilter { open, reviewed, scheduled, closed, all }

class DashboardSection extends StatelessWidget {
  const DashboardSection({
    super.key,
    required this.jobs,
    required this.employees,
    required this.cleaningRequests,
    required this.cleaningRequestFilter,
    required this.totalPendingJobs,
    required this.totalAssignedJobs,
    required this.totalInProgressJobs,
    required this.totalCompletedJobs,
    required this.totalOverdueJobs,
    required this.onCleaningRequestFilterChanged,
    required this.onUpdateCleaningRequestStatus,
    required this.onOpenJobsOverdue,
    required this.getClientNameById,
    required this.buildSectionHeader,
    required this.buildMetricTile,
  });

  final List<Job> jobs;
  final List<Employee> employees;
  final List<CleaningRequest> cleaningRequests;
  final CleaningRequestFilter cleaningRequestFilter;
  final int totalPendingJobs;
  final int totalAssignedJobs;
  final int totalInProgressJobs;
  final int totalCompletedJobs;
  final int totalOverdueJobs;
  final Function(CleaningRequestFilter) onCleaningRequestFilterChanged;
  final Function(CleaningRequest, String) onUpdateCleaningRequestStatus;
  final VoidCallback onOpenJobsOverdue;
  final String Function(int) getClientNameById;
  final Widget Function(String title, String subtitle) buildSectionHeader;
  final Widget Function({
    required String label,
    required String value,
    required IconData icon,
    required Color bg,
    required Color fg,
  }) buildMetricTile;

  bool _isOverdue(Job job) {
    if (job.status.trim().toLowerCase() == 'completed') return false;
    final scheduled = DateTime.tryParse(job.scheduledDate);
    if (scheduled == null) return false;
    return scheduled.isBefore(DateTime.now().subtract(const Duration(days: 1)));
  }

  List<CleaningRequest> get _filteredCleaningRequests {
    switch (cleaningRequestFilter) {
      case CleaningRequestFilter.open:
        return cleaningRequests.where((r) => r.status == 'OPEN').toList();
      case CleaningRequestFilter.reviewed:
        return cleaningRequests.where((r) => r.status == 'REVIEWED').toList();
      case CleaningRequestFilter.scheduled:
        return cleaningRequests.where((r) => r.status == 'SCHEDULED').toList();
      case CleaningRequestFilter.closed:
        return cleaningRequests.where((r) => r.status == 'CLOSED').toList();
      case CleaningRequestFilter.all:
        return cleaningRequests;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeEmployees = employees
        .where((e) => e.status.trim().toLowerCase() == 'active')
        .length;
    final overdueJobs = jobs.where(_isOverdue).toList()
      ..sort((a, b) {
        final aDate = DateTime.tryParse(a.scheduledDate);
        final bDate = DateTime.tryParse(b.scheduledDate);
        if (aDate == null || bDate == null) return 0;
        return aDate.compareTo(bDate);
      });
    final utilizationAssigned = activeEmployees == 0
        ? 0.0
        : (totalAssignedJobs / activeEmployees).clamp(0, 8) / 8;
    final utilizationCompleted = activeEmployees == 0
        ? 0.0
        : (totalCompletedJobs / activeEmployees).clamp(0, 8) / 8;

    return ListView(
      children: [
        buildSectionHeader(
          'Operations Dashboard',
          'Snapshot across all employees and all jobs.',
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                buildMetricTile(
                  label: 'Pending',
                  value: totalPendingJobs.toString(),
                  icon: Icons.pending_actions,
                  bg: const Color.fromRGBO(255, 249, 224, 1),
                  fg: const Color.fromRGBO(138, 92, 8, 1),
                ),
                buildMetricTile(
                  label: 'Assigned',
                  value: totalAssignedJobs.toString(),
                  icon: Icons.assignment_outlined,
                  bg: const Color.fromRGBO(255, 249, 224, 1),
                  fg: const Color.fromRGBO(138, 92, 8, 1),
                ),
                buildMetricTile(
                  label: 'In Progress',
                  value: totalInProgressJobs.toString(),
                  icon: Icons.timelapse_outlined,
                  bg: const Color.fromRGBO(231, 239, 252, 1),
                  fg: const Color.fromRGBO(31, 63, 122, 1),
                ),
                buildMetricTile(
                  label: 'Completed',
                  value: totalCompletedJobs.toString(),
                  icon: Icons.task_alt,
                  bg: const Color.fromRGBO(241, 236, 252, 1),
                  fg: const Color.fromRGBO(68, 46, 111, 1),
                ),
                buildMetricTile(
                  label: 'Overdue',
                  value: totalOverdueJobs.toString(),
                  icon: Icons.warning_amber_outlined,
                  bg: const Color.fromRGBO(255, 232, 238, 1),
                  fg: const Color.fromRGBO(156, 42, 74, 1),
                ),
                buildMetricTile(
                  label: 'Employees',
                  value: '${employees.length} total ($activeEmployees active)',
                  icon: Icons.groups_outlined,
                  bg: const Color.fromRGBO(231, 239, 252, 1),
                  fg: const Color.fromRGBO(31, 63, 122, 1),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Per-Employee Utilization (Placeholder)'),
                const SizedBox(height: 8),
                Text(
                  'Data source wiring pending: current bars use high-level averages.',
                  style: TextStyle(color: Theme.of(context).hintColor),
                ),
                const SizedBox(height: 12),
                const Text('Assigned capacity'),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: utilizationAssigned),
                const SizedBox(height: 10),
                const Text('Completed throughput'),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: utilizationCompleted),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cleaning Requests',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Open'),
                      selected: cleaningRequestFilter == CleaningRequestFilter.open,
                      onSelected: (_) => onCleaningRequestFilterChanged(CleaningRequestFilter.open),
                    ),
                    ChoiceChip(
                      label: const Text('Reviewed'),
                      selected: cleaningRequestFilter == CleaningRequestFilter.reviewed,
                      onSelected: (_) => onCleaningRequestFilterChanged(CleaningRequestFilter.reviewed),
                    ),
                    ChoiceChip(
                      label: const Text('Scheduled'),
                      selected: cleaningRequestFilter == CleaningRequestFilter.scheduled,
                      onSelected: (_) => onCleaningRequestFilterChanged(CleaningRequestFilter.scheduled),
                    ),
                    ChoiceChip(
                      label: const Text('Closed'),
                      selected: cleaningRequestFilter == CleaningRequestFilter.closed,
                      onSelected: (_) => onCleaningRequestFilterChanged(CleaningRequestFilter.closed),
                    ),
                    ChoiceChip(
                      label: const Text('All'),
                      selected: cleaningRequestFilter == CleaningRequestFilter.all,
                      onSelected: (_) => onCleaningRequestFilterChanged(CleaningRequestFilter.all),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_filteredCleaningRequests.isEmpty)
                  Text(
                    'No requests for the selected status.',
                    style: TextStyle(color: Theme.of(context).hintColor),
                  )
                else
                  ..._filteredCleaningRequests
                      .take(8)
                      .map(
                        (request) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFD1D9E6)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Request #${request.id}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Chip(
                                    visualDensity: VisualDensity.compact,
                                    label: Text(request.status),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${formatDateMdy(request.requestedDate)} • ${request.requestedTime}',
                                    style: TextStyle(
                                      color: Theme.of(context).hintColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${getClientNameById(request.clientId)} • ${request.requesterName}',
                              ),
                              Text(
                                '${request.requesterEmail} • ${request.requesterPhone}',
                                style: TextStyle(
                                  color: Theme.of(context).hintColor,
                                ),
                              ),
                              if ((request.cleaningDetails ?? '')
                                  .trim()
                                  .isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    request.cleaningDetails!.trim(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton(
                                    onPressed: request.status == 'REVIEWED'
                                        ? null
                                        : () => onUpdateCleaningRequestStatus(
                                            request,
                                            'REVIEWED',
                                          ),
                                    child: const Text('Mark Reviewed'),
                                  ),
                                  OutlinedButton(
                                    onPressed: request.status == 'SCHEDULED'
                                        ? null
                                        : () => onUpdateCleaningRequestStatus(
                                            request,
                                            'SCHEDULED',
                                          ),
                                    child: const Text('Mark Scheduled'),
                                  ),
                                  OutlinedButton(
                                    onPressed: request.status == 'CLOSED'
                                        ? null
                                        : () => onUpdateCleaningRequestStatus(
                                            request,
                                            'CLOSED',
                                          ),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick Late-Job List',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (overdueJobs.isEmpty)
                  Text(
                    'No overdue jobs right now.',
                    style: TextStyle(color: Theme.of(context).hintColor),
                  )
                else
                  ...overdueJobs
                      .take(5)
                      .map(
                        (job) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(job.jobNumber),
                          subtitle: Text(
                            '${job.clientName ?? 'Unknown client'} • ${formatDateMdy(job.scheduledDate)}',
                          ),
                        ),
                      ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: onOpenJobsOverdue,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open Overdue Jobs'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reporting Stubs',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    Chip(
                      backgroundColor: Color.fromRGBO(231, 239, 252, 1),
                      labelStyle: TextStyle(
                        color: Color.fromRGBO(31, 63, 122, 1),
                        fontWeight: FontWeight.w600,
                      ),
                      label: Text('Operations Summary (Stub)'),
                    ),
                    Chip(
                      backgroundColor: Color.fromRGBO(231, 239, 252, 1),
                      labelStyle: TextStyle(
                        color: Color.fromRGBO(31, 63, 122, 1),
                        fontWeight: FontWeight.w600,
                      ),
                      label: Text('Payroll Window Export (Stub)'),
                    ),
                    Chip(
                      backgroundColor: Color.fromRGBO(231, 239, 252, 1),
                      labelStyle: TextStyle(
                        color: Color.fromRGBO(31, 63, 122, 1),
                        fontWeight: FontWeight.w600,
                      ),
                      label: Text('Client Service Recap (Stub)'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
