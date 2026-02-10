import 'package:flutter/material.dart';
import '../../../models/employee.dart';
import '../../../models/client.dart';
import '../../../models/location.dart';
import '../../../models/job.dart';
import '../../../utils/date_format.dart';
import '../../common/sortable_entity_table.dart';

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
    required this.employeesSortColumnIndex,
    required this.employeesSortAscending,
    required this.locationsSortColumnIndex,
    required this.locationsSortAscending,
    required this.activeOnlyFilter,
    required this.locationFilter,
    required this.onManagementModelChanged,
    required this.onActiveOnlyFilterChanged,
    required this.onLocationFilterChanged,
    required this.onJobFilterChanged,
    required this.onJobClientSearchChanged,
    required this.onEmployeeSearchChanged,
    required this.onClientSearchChanged,
    required this.onLocationSearchChanged,
    required this.onJobDateRangeChanged,
    required this.onJobsSort,
    required this.onClientsSort,
    required this.onEmployeesSort,
    required this.onLocationsSort,
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
  final int? employeesSortColumnIndex;
  final bool employeesSortAscending;
  final int? locationsSortColumnIndex;
  final bool locationsSortAscending;
  final bool activeOnlyFilter;
  final String locationFilter;
  final Function(ManagementModel) onManagementModelChanged;
  final Function(bool) onActiveOnlyFilterChanged;
  final Function(String) onLocationFilterChanged;
  final Function(String) onJobFilterChanged;
  final Function(String) onJobClientSearchChanged;
  final Function(String) onEmployeeSearchChanged;
  final Function(String) onClientSearchChanged;
  final Function(String) onLocationSearchChanged;
  final Function(DateTimeRange) onJobDateRangeChanged;
  final Function(int, bool) onJobsSort;
  final Function(int, bool) onClientsSort;
  final Function(int, bool) onEmployeesSort;
  final Function(int, bool) onLocationsSort;
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
                                // Different filter chips for Jobs vs Locations vs other entities
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
                                ] else if (managementModel ==
                                    ManagementModel.locations) ...[
                                  ChoiceChip(
                                    label: const Text('Active'),
                                    selected: locationFilter == 'active',
                                    onSelected: (_) =>
                                        onLocationFilterChanged('active'),
                                  ),
                                  ChoiceChip(
                                    label: const Text('Inactive'),
                                    selected: locationFilter == 'inactive',
                                    onSelected: (_) =>
                                        onLocationFilterChanged('inactive'),
                                  ),
                                  ChoiceChip(
                                    label: const Text('All'),
                                    selected: locationFilter == 'all',
                                    onSelected: (_) =>
                                        onLocationFilterChanged('all'),
                                  ),
                                  ChoiceChip(
                                    label: const Text('Deleted'),
                                    selected: locationFilter == 'deleted',
                                    onSelected: (_) =>
                                        onLocationFilterChanged('deleted'),
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
    return switch (managementModel) {
      ManagementModel.employees => SortableEntityTable(
        items: filteredEmployees,
        columns: const [
          TableColumnConfig(label: '', index: 0, sortable: true),
          TableColumnConfig(label: '', index: 1, sortable: false),
          TableColumnConfig(label: 'Name', index: 2, sortable: true),
          TableColumnConfig(label: 'Email', index: 3, sortable: true),
          TableColumnConfig(label: 'Phone', index: 4, sortable: true),
          TableColumnConfig(label: '', index: 5, sortable: false),
        ],
        sortColumnIndex: employeesSortColumnIndex,
        sortAscending: employeesSortAscending,
        onSort: onEmployeesSort,
        buildCells: (context, emp) => [
          SortableEntityTable.buildStatusCell(emp.status, context),
          SortableEntityTable.buildPhotoCell(
            context: context,
            photoUrl: emp.photoUrl,
            initial: emp.name,
          ),
          DataCell(Text(emp.name)),
          DataCell(Text(emp.email ?? '')),
          DataCell(Text(emp.phoneNumber ?? '')),
          SortableEntityTable.buildDetailsCell(
            onPressed: () => onShowEditDialog(emp),
          ),
        ],
      ),
      ManagementModel.clients => SortableEntityTable(
        items: filteredClients,
        columns: const [
          TableColumnConfig(label: '', index: 0, sortable: true),
          TableColumnConfig(label: 'Name', index: 1, sortable: true),
          TableColumnConfig(label: 'Email', index: 2, sortable: true),
          TableColumnConfig(label: 'Phone', index: 3, sortable: true),
          TableColumnConfig(label: '', index: 4, sortable: false),
        ],
        sortColumnIndex: clientsSortColumnIndex,
        sortAscending: clientsSortAscending,
        onSort: onClientsSort,
        buildCells: (context, client) => [
          SortableEntityTable.buildStatusCell(client.status, context),
          DataCell(Text(client.name)),
          DataCell(Text(client.email ?? '')),
          DataCell(Text(client.phoneNumber ?? '')),
          SortableEntityTable.buildDetailsCell(
            onPressed: () => onShowEditClientDialog(client),
          ),
        ],
      ),
      ManagementModel.locations => SortableEntityTable(
        items: filteredLocations,
        columns: const [
          TableColumnConfig(label: '', index: 0, sortable: true),
          TableColumnConfig(label: '', index: 1, sortable: false),
          TableColumnConfig(label: 'Client Name', index: 2, sortable: true),
          TableColumnConfig(label: 'Address', index: 3, sortable: true),
          TableColumnConfig(label: '', index: 4, sortable: false),
        ],
        sortColumnIndex: locationsSortColumnIndex,
        sortAscending: locationsSortAscending,
        onSort: onLocationsSort,
        buildCells: (context, loc) {
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

          return [
            SortableEntityTable.buildStatusCell(loc.status, context),
            DataCell(
              loc.photoUrl != null && loc.photoUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: loc.photoUrl!.startsWith('/assets/')
                          ? Image.asset(
                              loc.photoUrl!.replaceFirst('/', ''),
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                            )
                          : Image.network(
                              loc.photoUrl!,
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                            ),
                    )
                  : Icon(
                      Icons.location_on,
                      size: 24,
                      color: Theme.of(context).colorScheme.primaryContainer,
                    ),
            ),
            DataCell(Text(getLocationLabel(loc.clientId))),
            DataCell(
              Text(fullAddress, overflow: TextOverflow.ellipsis, maxLines: 2),
            ),
            SortableEntityTable.buildDetailsCell(
              onPressed: () => onShowEditLocationDialog(loc),
            ),
          ];
        },
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

    return SortableEntityTable(
      items: filteredJobs,
      columns: const [
        TableColumnConfig(label: '', index: 0, sortable: true),
        TableColumnConfig(label: 'Date', index: 1, sortable: true),
        TableColumnConfig(label: 'Client', index: 2, sortable: true),
        TableColumnConfig(label: 'Location', index: 3, sortable: true),
        TableColumnConfig(label: 'Cleaner', index: 4, sortable: true),
        TableColumnConfig(label: 'Estimated\nDuration', index: 5, sortable: true),
        TableColumnConfig(label: 'Actual\nDuration', index: 6, sortable: true),
        TableColumnConfig(label: '', index: 7, sortable: false),
      ],
      sortColumnIndex: jobsSortColumnIndex,
      sortAscending: jobsSortAscending,
      onSort: onJobsSort,
      buildCells: (context, job) {
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

        final displayStatus = isOverdue(job) ? 'overdue' : job.status;

        return [
          SortableEntityTable.buildStatusCell(displayStatus, context),
          DataCell(Text(formatDateMdy(job.scheduledDate))),
          DataCell(Text(job.clientName ?? 'N/A')),
          DataCell(
            Text(fullLocation, overflow: TextOverflow.ellipsis, maxLines: 2),
          ),
          DataCell(Text(cleanerDisplay)),
          DataCell(Text(minutesLabel(job.estimatedDurationMinutes))),
          DataCell(Text(minutesLabel(job.actualDurationMinutes))),
          SortableEntityTable.buildDetailsCell(
            onPressed: () => onShowEditJobDialog(job),
          ),
        ];
      },
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
}
