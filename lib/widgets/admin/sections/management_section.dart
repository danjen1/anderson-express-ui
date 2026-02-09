import 'package:flutter/material.dart';
import '../../../models/employee.dart';
import '../../../models/client.dart';
import '../../../models/location.dart';
import '../../../models/job.dart';
import '../../../utils/date_format.dart';

enum ManagementModel { employees, clients, locations, jobs }

class ManagementSection extends StatelessWidget {
  const ManagementSection({
    super.key,
    required this.managementModel,
    required this.filteredEmployees,
    required this.filteredClients,
    required this.filteredLocations,
    required this.filteredJobs,
    required this.jobAssignments,
    required this.jobDateRange,
    required this.jobFilter,
    required this.jobClientSearch,
    required this.employeeSearch,
    required this.clientSearch,
    required this.locationSearch,
    required this.jobsSortColumnIndex,
    required this.jobsSortAscending,
    required this.clientsSortColumnIndex,
    required this.clientsSortAscending,
    required this.activeOnlyFilter,
    required this.onManagementModelChanged,
    required this.onActiveOnlyFilterChanged,
    required this.onJobFilterChanged,
    required this.onJobClientSearchChanged,
    required this.onEmployeeSearchChanged,
    required this.onClientSearchChanged,
    required this.onLocationSearchChanged,
    required this.onJobDateRangeChanged,
    required this.onJobsSort,
    required this.onClientsSort,
    required this.onShowCreateDialog,
    required this.onShowCreateClientDialog,
    required this.onShowCreateLocationDialog,
    required this.onShowCreateJobDialog,
    required this.onShowEditDialog,
    required this.onShowEditClientDialog,
    required this.onShowEditLocationDialog,
    required this.onShowEditJobDialog,
    required this.onDeleteEmployee,
    required this.onDeleteClient,
    required this.onDeleteLocation,
    required this.onDeleteJob,
    required this.buildSectionHeader,
    required this.buildCenteredSection,
    required this.buildTableColumn,
    required this.buildRowActionButton,
    required this.getLocationLabel,
    required this.isOverdue,
  });

  final ManagementModel managementModel;
  final List<Employee> filteredEmployees;
  final List<Client> filteredClients;
  final List<Location> filteredLocations;
  final List<Job> filteredJobs;
  final Map<String, List<String>> jobAssignments;
  final DateTimeRange jobDateRange;
  final String jobFilter;
  final String jobClientSearch;
  final String employeeSearch;
  final String clientSearch;
  final String locationSearch;
  final int? jobsSortColumnIndex;
  final bool jobsSortAscending;
  final int? clientsSortColumnIndex;
  final bool clientsSortAscending;
  final bool activeOnlyFilter;
  final Function(ManagementModel) onManagementModelChanged;
  final Function(bool) onActiveOnlyFilterChanged;
  final Function(String) onJobFilterChanged;
  final Function(String) onJobClientSearchChanged;
  final Function(String) onEmployeeSearchChanged;
  final Function(String) onClientSearchChanged;
  final Function(String) onLocationSearchChanged;
  final Function(DateTimeRange) onJobDateRangeChanged;
  final Function(int, bool) onJobsSort;
  final Function(int, bool) onClientsSort;
  final VoidCallback onShowCreateDialog;
  final VoidCallback onShowCreateClientDialog;
  final VoidCallback onShowCreateLocationDialog;
  final VoidCallback onShowCreateJobDialog;
  final Function(Employee) onShowEditDialog;
  final Function(Client) onShowEditClientDialog;
  final Function(Location) onShowEditLocationDialog;
  final Function(Job) onShowEditJobDialog;
  final Function(Employee) onDeleteEmployee;
  final Function(Client) onDeleteClient;
  final Function(Location) onDeleteLocation;
  final Function(Job) onDeleteJob;
  final Widget Function(String title, String subtitle) buildSectionHeader;
  final Widget Function(Widget child) buildCenteredSection;
  final DataColumn Function(String) buildTableColumn;
  final Widget Function({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  })
  buildRowActionButton;
  final String Function(int?) getLocationLabel;
  final bool Function(Job) isOverdue;

  @override
  Widget build(BuildContext context) {
    final rowsCount = switch (managementModel) {
      ManagementModel.employees => filteredEmployees.length,
      ManagementModel.clients => filteredClients.length,
      ManagementModel.locations => filteredLocations.length,
      ManagementModel.jobs => filteredJobs.length,
    };

    final createButton = switch (managementModel) {
      ManagementModel.employees => (
        label: 'Create Employee',
        icon: Icons.person_add,
        onPressed: onShowCreateDialog,
      ),
      ManagementModel.clients => (
        label: 'Create Client',
        icon: Icons.business,
        onPressed: onShowCreateClientDialog,
      ),
      ManagementModel.locations => (
        label: 'Create Location',
        icon: Icons.add_location_alt,
        onPressed: onShowCreateLocationDialog,
      ),
      ManagementModel.jobs => (
        label: 'Create Job',
        icon: Icons.work_outline,
        onPressed: onShowCreateJobDialog,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionHeader(
          'Management',
          'Manage employees, clients, locations, and jobs.',
        ),
        Expanded(
          child: buildCenteredSection(
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: Dropdown | Create Button
                        Row(
                          children: [
                            SizedBox(
                              width: 250,
                              child: DropdownButtonFormField<ManagementModel>(
                                initialValue: managementModel,
                                decoration: const InputDecoration(
                                  labelText: 'Management Type',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: ManagementModel.jobs,
                                    child: Text('Jobs'),
                                  ),
                                  DropdownMenuItem(
                                    value: ManagementModel.clients,
                                    child: Text('Clients'),
                                  ),
                                  DropdownMenuItem(
                                    value: ManagementModel.locations,
                                    child: Text('Locations'),
                                  ),
                                  DropdownMenuItem(
                                    value: ManagementModel.employees,
                                    child: Text('Employees'),
                                  ),
                                ],
                                onChanged: (next) {
                                  if (next == null) return;
                                  onManagementModelChanged(next);
                                },
                              ),
                            ),
                            const Spacer(),
                            FilledButton.icon(
                              onPressed: createButton.onPressed,
                              icon: Icon(createButton.icon),
                              label: Text(createButton.label),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Row 2: Record Count | Date Picker (Jobs only)
                        Row(
                          children: [
                            Text(
                              '$rowsCount ${switch (managementModel) {
                                ManagementModel.jobs => 'Jobs',
                                ManagementModel.clients => 'Clients',
                                ManagementModel.locations => 'Locations',
                                ManagementModel.employees => 'Employees',
                              }}',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            if (managementModel == ManagementModel.jobs)
                              _buildJobDateRangePicker(context),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Row 3: Status Filters | Search Box
                        Row(
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // Different filter chips for Jobs vs other entities
                                if (managementModel ==
                                    ManagementModel.jobs) ...[
                                  ChoiceChip(
                                    label: const Text('Active'),
                                    selected: jobFilter == 'active',
                                    onSelected: (_) =>
                                        onJobFilterChanged('active'),
                                  ),
                                  ChoiceChip(
                                    label: const Text('All'),
                                    selected: jobFilter == 'all',
                                    onSelected: (_) =>
                                        onJobFilterChanged('all'),
                                  ),
                                ] else ...[
                                  ChoiceChip(
                                    label: const Text('Active'),
                                    selected: activeOnlyFilter,
                                    onSelected: (_) =>
                                        onActiveOnlyFilterChanged(true),
                                  ),
                                  ChoiceChip(
                                    label: const Text('All'),
                                    selected: !activeOnlyFilter,
                                    onSelected: (_) =>
                                        onActiveOnlyFilterChanged(false),
                                  ),
                                ],
                              ],
                            ),
                            const Spacer(),
                            // Search box for all entity types
                            SizedBox(
                              width: 285,
                              child: TextField(
                                onChanged: switch (managementModel) {
                                  ManagementModel.jobs =>
                                    onJobClientSearchChanged,
                                  ManagementModel.employees =>
                                    onEmployeeSearchChanged,
                                  ManagementModel.clients =>
                                    onClientSearchChanged,
                                  ManagementModel.locations =>
                                    onLocationSearchChanged,
                                },
                                decoration: InputDecoration(
                                  hintText: switch (managementModel) {
                                    ManagementModel.jobs => 'Search clients...',
                                    ManagementModel.employees =>
                                      'Search employees...',
                                    ManagementModel.clients =>
                                      'Search clients...',
                                    ManagementModel.locations =>
                                      'Search addresses...',
                                  },
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    size: 20,
                                  ),
                                  suffixIcon: switch (managementModel) {
                                    ManagementModel.jobs =>
                                      jobClientSearch.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(
                                                Icons.clear,
                                                size: 20,
                                              ),
                                              onPressed: () =>
                                                  onJobClientSearchChanged(''),
                                            )
                                          : null,
                                    ManagementModel.employees =>
                                      employeeSearch.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(
                                                Icons.clear,
                                                size: 20,
                                              ),
                                              onPressed: () =>
                                                  onEmployeeSearchChanged(''),
                                            )
                                          : null,
                                    ManagementModel.clients =>
                                      clientSearch.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(
                                                Icons.clear,
                                                size: 20,
                                              ),
                                              onPressed: () =>
                                                  onClientSearchChanged(''),
                                            )
                                          : null,
                                    ManagementModel.locations =>
                                      locationSearch.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(
                                                Icons.clear,
                                                size: 20,
                                              ),
                                              onPressed: () =>
                                                  onLocationSearchChanged(''),
                                            )
                                          : null,
                                  },
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: rowsCount == 0
                              ? Center(
                                  child: Text(
                                    'No items to display.',
                                    style: TextStyle(
                                      color: Theme.of(context).hintColor,
                                    ),
                                  ),
                                )
                              : SingleChildScrollView(
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: _buildTable(context),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTable(BuildContext context) {
    // Helper function for client status badges
    ({String label, Color bg, Color fg, Color border}) clientStatusBadge(String status) {
      final dark = Theme.of(context).brightness == Brightness.dark;
      final statusLower = status.trim().toLowerCase();
      
      return switch (statusLower) {
        'active' => (
          label: 'A',
          bg: dark ? const Color(0xFF2C4A40) : const Color(0xFFDBF3E8),
          fg: dark ? const Color(0xFFE4E4E4) : const Color(0xFF1E6A4F),
          border: dark ? const Color(0xFF6DB598) : const Color(0xFF49A07D),
        ),
        'invited' => (
          label: 'V',
          bg: dark ? const Color(0xFF3D3550) : const Color(0xFFE8DDF7),
          fg: dark ? const Color(0xFFE4E4E4) : const Color(0xFF442E6F),
          border: dark ? const Color(0xFF8C74B2) : const Color(0xFF7A56A5),
        ),
        'inactive' => (
          label: 'I',
          bg: dark ? const Color(0xFF41424B) : const Color(0xFFE9EEF2),
          fg: dark ? const Color(0xFFE4E4E4) : const Color(0xFF41588E),
          border: dark ? const Color(0xFF7A7E8C) : const Color(0xFFBEDCE4),
        ),
        'deleted' => (
          label: 'D',
          bg: dark ? const Color(0xFF4A2D35) : const Color(0xFFFFE5EC),
          fg: dark ? const Color(0xFFFFC1CC) : const Color(0xFFE63721),
          border: dark ? const Color(0xFFB85B74) : const Color(0xFFE63721),
        ),
        _ => (
          label: '?',
          bg: dark ? const Color(0xFF41424B) : const Color(0xFFE9EEF2),
          fg: dark ? const Color(0xFFE4E4E4) : const Color(0xFF41588E),
          border: dark ? const Color(0xFF7A7E8C) : const Color(0xFFBEDCE4),
        ),
      };
    }

    return switch (managementModel) {
      ManagementModel.employees => DataTable(
        headingTextStyle: const TextStyle(fontWeight: FontWeight.w700),
        columnSpacing: 32,
        columns: [
          buildTableColumn(''),
          buildTableColumn('Name'),
          buildTableColumn('Email'),
          buildTableColumn('Employee #'),
          buildTableColumn(''),
        ],
        rows: filteredEmployees
            .map(
              (emp) => DataRow(
                cells: [
                  DataCell(
                    _statusIndicator(
                      context,
                      emp.status.trim().toLowerCase() == 'active',
                    ),
                  ),
                  DataCell(Text(emp.name)),
                  DataCell(Text(emp.email ?? '')),
                  DataCell(Text(emp.employeeNumber)),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 20),
                      tooltip: 'View Details',
                      onPressed: () => onShowEditDialog(emp),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
      ManagementModel.clients => DataTable(
        headingTextStyle: const TextStyle(fontWeight: FontWeight.w700),
        columnSpacing: 32,
        sortColumnIndex: clientsSortColumnIndex,
        sortAscending: clientsSortAscending,
        columns: [
          DataColumn(
            label: const Text(''),
            onSort: (columnIndex, ascending) => onClientsSort(columnIndex, ascending),
          ),
          DataColumn(
            label: const Text('Name'),
            onSort: (columnIndex, ascending) => onClientsSort(columnIndex, ascending),
          ),
          DataColumn(
            label: const Text('Email'),
            onSort: (columnIndex, ascending) => onClientsSort(columnIndex, ascending),
          ),
          DataColumn(
            label: const Text('Phone'),
            onSort: (columnIndex, ascending) => onClientsSort(columnIndex, ascending),
          ),
          const DataColumn(label: Text('')),
        ],
        rows: filteredClients
            .map(
              (client) {
                final badge = clientStatusBadge(client.status);
                return DataRow(
                  cells: [
                    DataCell(
                      Container(
                        padding: EdgeInsets.zero,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: badge.bg,
                            shape: BoxShape.circle,
                            border: Border.all(color: badge.border, width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              badge.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: badge.fg,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text(client.name)),
                    DataCell(Text(client.email ?? '')),
                    DataCell(Text(client.phoneNumber ?? '')),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined, size: 20),
                        tooltip: 'View Details',
                        onPressed: () => onShowEditClientDialog(client),
                      ),
                    ),
                  ],
                );
              },
            )
            .toList(),
      ),
      ManagementModel.locations => DataTable(
        headingTextStyle: const TextStyle(fontWeight: FontWeight.w700),
        columnSpacing: 32,
        columns: [
          buildTableColumn(''),
          buildTableColumn('Address'),
          buildTableColumn('Client'),
          buildTableColumn(''),
        ],
        rows: filteredLocations.map((loc) {
          // Build full address
          final addressParts = <String>[];
          if (loc.address != null && loc.address!.isNotEmpty) {
            addressParts.add(loc.address!);
          }
          final cityStateZip = <String>[];
          if (loc.city != null && loc.city!.isNotEmpty) {
            cityStateZip.add(loc.city!);
          }
          if (loc.state != null && loc.state!.isNotEmpty) {
            cityStateZip.add(loc.state!);
          }
          if (loc.zipCode != null && loc.zipCode!.isNotEmpty) {
            cityStateZip.add(loc.zipCode!);
          }
          if (cityStateZip.isNotEmpty) {
            addressParts.add(cityStateZip.join(' '));
          }
          final fullAddress = addressParts.isEmpty
              ? 'N/A'
              : addressParts.join(', ');

          return DataRow(
            cells: [
              DataCell(
                _statusIndicator(
                  context,
                  loc.status.trim().toLowerCase() == 'active',
                ),
              ),
              DataCell(
                Text(fullAddress, overflow: TextOverflow.ellipsis, maxLines: 2),
              ),
              DataCell(Text(getLocationLabel(loc.clientId))),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.visibility_outlined, size: 20),
                  tooltip: 'View Details',
                  onPressed: () => onShowEditLocationDialog(loc),
                ),
              ),
            ],
          );
        }).toList(),
      ),
      ManagementModel.jobs => _buildJobsTable(context),
    };
  }

  Widget _buildJobsTable(BuildContext context) {
    String minutesLabel(int? value) {
      if (value == null || value < 0) return '—';
      final hours = value ~/ 60;
      final minutes = value % 60;
      if (hours == 0) return '${minutes}m';
      return '${hours}h ${minutes}m';
    }

    ({String label, Color bg, Color fg, Color border}) statusBadge(Job job) {
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

    return DataTable(
      sortColumnIndex: jobsSortColumnIndex,
      sortAscending: jobsSortAscending,
      headingTextStyle: const TextStyle(fontWeight: FontWeight.w700),
      columnSpacing: 12,
      columns: [
        DataColumn(
          label: const Text(''),
          onSort: (columnIndex, ascending) =>
              onJobsSort(columnIndex, ascending),
        ),
        DataColumn(
          label: const Text('Date'),
          onSort: (columnIndex, ascending) =>
              onJobsSort(columnIndex, ascending),
        ),
        DataColumn(
          label: const Text('Client'),
          onSort: (columnIndex, ascending) =>
              onJobsSort(columnIndex, ascending),
        ),
        DataColumn(
          label: const Text('Location'),
          onSort: (columnIndex, ascending) =>
              onJobsSort(columnIndex, ascending),
        ),
        DataColumn(
          label: const Text('Cleaner'),
          onSort: (columnIndex, ascending) =>
              onJobsSort(columnIndex, ascending),
        ),
        DataColumn(
          label: const Text('Estimated\nDuration'),
          onSort: (columnIndex, ascending) =>
              onJobsSort(columnIndex, ascending),
        ),
        DataColumn(
          label: const Text('Actual\nDuration'),
          onSort: (columnIndex, ascending) =>
              onJobsSort(columnIndex, ascending),
        ),
        const DataColumn(label: Text('')),
      ],
      rows: filteredJobs.map((job) {
        final badge = statusBadge(job);
        final assignedCleaners = jobAssignments[job.id] ?? [];
        final cleanerDisplay = assignedCleaners.isEmpty
            ? 'Unassigned'
            : assignedCleaners.join(', ');

        // Build full location string
        final locationParts = <String>[];
        if (job.locationAddress != null && job.locationAddress!.isNotEmpty) {
          locationParts.add(job.locationAddress!);
        }
        final cityStateZip = <String>[];
        if (job.locationCity != null && job.locationCity!.isNotEmpty) {
          cityStateZip.add(job.locationCity!);
        }
        if (cityStateZip.isNotEmpty) {
          locationParts.add(cityStateZip.join(' '));
        }
        final fullLocation = locationParts.isEmpty
            ? 'N/A'
            : locationParts.join(', ');

        return DataRow(
          cells: [
            DataCell(
              Container(
                padding: EdgeInsets.zero,
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: badge.bg,
                    border: Border.all(color: badge.border, width: 1.5),
                    borderRadius: BorderRadius.circular(10),
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
            ),
            DataCell(Text(formatDateMdy(job.scheduledDate))),
            DataCell(Text(job.clientName ?? 'N/A')),
            DataCell(
              Text(fullLocation, overflow: TextOverflow.ellipsis, maxLines: 2),
            ),
            DataCell(Text(cleanerDisplay)),
            DataCell(Text(minutesLabel(job.estimatedDurationMinutes))),
            DataCell(Text(minutesLabel(job.actualDurationMinutes))),
            DataCell(
              IconButton(
                icon: const Icon(Icons.visibility_outlined, size: 20),
                tooltip: 'View Details',
                onPressed: () => onShowEditJobDialog(job),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildJobDateRangePicker(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: jobDateRange.start,
              firstDate: DateTime(2020),
              lastDate: DateTime(2050),
            );
            if (picked != null) {
              onJobDateRangeChanged(
                DateTimeRange(start: picked, end: jobDateRange.end),
              );
            }
          },
          icon: const Icon(Icons.date_range, size: 16),
          label: Text(
            '${jobDateRange.start.month}-${jobDateRange.start.day}-${jobDateRange.start.year}',
          ),
        ),
        const Text('to'),
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: jobDateRange.end,
              firstDate: DateTime(2020),
              lastDate: DateTime(2050),
            );
            if (picked != null) {
              onJobDateRangeChanged(
                DateTimeRange(start: jobDateRange.start, end: picked),
              );
            }
          },
          icon: const Icon(Icons.date_range, size: 16),
          label: Text(
            '${jobDateRange.end.month}-${jobDateRange.end.day}-${jobDateRange.end.year}',
          ),
        ),
      ],
    );
  }

  Widget _statusIndicator(BuildContext context, bool isActive) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: isActive
            ? (dark ? const Color(0xFF6DB598) : const Color(0xFF49A07D))
            : (dark ? const Color(0xFF7A7E8C) : const Color(0xFFBEDCE4)),
        shape: BoxShape.circle,
      ),
    );
  }
}
