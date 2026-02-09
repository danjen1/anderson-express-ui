import 'package:flutter/material.dart';
import '../../../models/employee.dart';
import '../../../models/client.dart';
import '../../../models/location.dart';

enum ManagementModel { employees, clients, locations }

class ManagementSection extends StatelessWidget {
  const ManagementSection({
    super.key,
    required this.managementModel,
    required this.filteredEmployees,
    required this.filteredClients,
    required this.filteredLocations,
    required this.activeOnlyFilter,
    required this.onManagementModelChanged,
    required this.onActiveOnlyFilterChanged,
    required this.onShowCreateDialog,
    required this.onShowCreateClientDialog,
    required this.onShowCreateLocationDialog,
    required this.onShowEditDialog,
    required this.onShowEditClientDialog,
    required this.onShowEditLocationDialog,
    required this.onDeleteEmployee,
    required this.onDeleteClient,
    required this.onDeleteLocation,
    required this.buildSectionHeader,
    required this.buildCenteredSection,
    required this.buildTableColumn,
    required this.buildRowActionButton,
    required this.getLocationLabel,
  });

  final ManagementModel managementModel;
  final List<Employee> filteredEmployees;
  final List<Client> filteredClients;
  final List<Location> filteredLocations;
  final bool activeOnlyFilter;
  final Function(ManagementModel) onManagementModelChanged;
  final Function(bool) onActiveOnlyFilterChanged;
  final VoidCallback onShowCreateDialog;
  final VoidCallback onShowCreateClientDialog;
  final VoidCallback onShowCreateLocationDialog;
  final Function(Employee) onShowEditDialog;
  final Function(Client) onShowEditClientDialog;
  final Function(Location) onShowEditLocationDialog;
  final Function(Employee) onDeleteEmployee;
  final Function(Client) onDeleteClient;
  final Function(Location) onDeleteLocation;
  final Widget Function(String title, String subtitle) buildSectionHeader;
  final Widget Function(Widget child) buildCenteredSection;
  final DataColumn Function(String) buildTableColumn;
  final Widget Function({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) buildRowActionButton;
  final String Function(int?) getLocationLabel;

  String get _managementModelSubtitle {
    return switch (managementModel) {
      ManagementModel.employees =>
        '${filteredEmployees.length} employee(s) displayed.',
      ManagementModel.clients => '${filteredClients.length} client(s) displayed.',
      ManagementModel.locations =>
        '${filteredLocations.length} location(s) displayed.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final rowsCount = switch (managementModel) {
      ManagementModel.employees => filteredEmployees.length,
      ManagementModel.clients => filteredClients.length,
      ManagementModel.locations => filteredLocations.length,
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
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionHeader(
          'People & Places',
          'Manage employees, clients, and locations.',
        ),
        Expanded(
          child: buildCenteredSection(
            SizedBox(
              width: double.infinity,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 300,
                            child: DropdownButtonFormField<ManagementModel>(
                              initialValue: managementModel,
                              decoration: const InputDecoration(
                                labelText: 'Management Type',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: ManagementModel.employees,
                                  child: Text('Employees'),
                                ),
                                DropdownMenuItem(
                                  value: ManagementModel.clients,
                                  child: Text('Clients'),
                                ),
                                DropdownMenuItem(
                                  value: ManagementModel.locations,
                                  child: Text('Locations'),
                                ),
                              ],
                              onChanged: (next) {
                                if (next == null) return;
                                onManagementModelChanged(next);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _managementModelSubtitle,
                              style: TextStyle(
                                color: Theme.of(context).hintColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: createButton.onPressed,
                            icon: Icon(createButton.icon),
                            label: Text(createButton.label),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
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
      ],
    );
  }

  Widget _buildTable(BuildContext context) {
    return switch (managementModel) {
      ManagementModel.employees => DataTable(
          headingTextStyle: const TextStyle(fontWeight: FontWeight.w700),
          columns: [
            buildTableColumn(''),
            buildTableColumn('Name'),
            buildTableColumn('Email'),
            buildTableColumn('Phone'),
            buildTableColumn('Employee #'),
            buildTableColumn('Actions'),
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
                    DataCell(Text(emp.phoneNumber ?? '')),
                    DataCell(Text(emp.employeeNumber)),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          buildRowActionButton(
                            icon: Icons.edit,
                            tooltip: 'Edit',
                            onPressed: () => onShowEditDialog(emp),
                          ),
                          const SizedBox(width: 10),
                          buildRowActionButton(
                            icon: Icons.delete,
                            tooltip: 'Delete',
                            onPressed: () => onDeleteEmployee(emp),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ManagementModel.clients => DataTable(
          headingTextStyle: const TextStyle(fontWeight: FontWeight.w700),
          columns: [
            buildTableColumn(''),
            buildTableColumn('Name'),
            buildTableColumn('Email'),
            buildTableColumn('Phone'),
            buildTableColumn('Actions'),
          ],
          rows: filteredClients
              .map(
                (client) => DataRow(
                  cells: [
                    DataCell(
                      _statusIndicator(
                        context,
                        client.status.trim().toLowerCase() == 'active',
                      ),
                    ),
                    DataCell(Text(client.name)),
                    DataCell(Text(client.email ?? '')),
                    DataCell(Text(client.phoneNumber ?? '')),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          buildRowActionButton(
                            icon: Icons.edit,
                            tooltip: 'Edit',
                            onPressed: () => onShowEditClientDialog(client),
                          ),
                          const SizedBox(width: 10),
                          buildRowActionButton(
                            icon: Icons.delete,
                            tooltip: 'Delete',
                            onPressed: () => onDeleteClient(client),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ManagementModel.locations => DataTable(
          headingTextStyle: const TextStyle(fontWeight: FontWeight.w700),
          columns: [
            buildTableColumn(''),
            buildTableColumn('Address'),
            buildTableColumn('City'),
            buildTableColumn('State'),
            buildTableColumn('Client'),
            buildTableColumn('Type'),
            buildTableColumn('Actions'),
          ],
          rows: filteredLocations
              .map(
                (loc) => DataRow(
                  cells: [
                    DataCell(
                      _statusIndicator(
                        context,
                        loc.status.trim().toLowerCase() == 'active',
                      ),
                    ),
                    DataCell(Text(loc.address ?? '')),
                    DataCell(Text(loc.city ?? '')),
                    DataCell(Text(loc.state ?? '')),
                    DataCell(Text(getLocationLabel(loc.clientId))),
                    DataCell(Text('')),  // Location type not in model
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          buildRowActionButton(
                            icon: Icons.edit,
                            tooltip: 'Edit',
                            onPressed: () => onShowEditLocationDialog(loc),
                          ),
                          const SizedBox(width: 10),
                          buildRowActionButton(
                            icon: Icons.delete,
                            tooltip: 'Delete',
                            onPressed: () => onDeleteLocation(loc),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
    };
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
