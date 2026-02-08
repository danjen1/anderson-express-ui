import 'package:flutter/material.dart';

import '../models/backend_config.dart';
import '../models/client.dart';
import '../models/employee.dart';
import '../models/job.dart';
import '../models/location.dart';
import '../services/api_service.dart';
import '../services/app_env.dart';
import '../services/auth_session.dart';
import '../services/backend_runtime.dart';
import '../utils/date_format.dart';
import '../utils/error_text.dart';
import '../widgets/backend_banner.dart';
import '../widgets/demo_mode_notice.dart';

enum _AdminSection {
  dashboard,
  jobs,
  cleaningProfiles,
  clients,
  employees,
  locations,
  reports,
}

enum _EmployeeFilter { all, active, inactive }

enum _ClientFilter { all, active, inactive }

enum _LocationFilter { all, active, inactive }

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late BackendKind _selectedBackend;
  late final TextEditingController _hostController;

  BackendConfig get _backend => BackendRuntime.config;
  ApiService get _api => ApiService();

  bool _loading = false;
  String? _error;
  List<Employee> _employees = const [];
  List<Job> _jobs = const [];
  List<Client> _clients = const [];
  List<Location> _locations = const [];
  _AdminSection _selectedSection = _AdminSection.dashboard;
  _EmployeeFilter _employeeFilter = _EmployeeFilter.all;
  _ClientFilter _clientFilter = _ClientFilter.all;
  _LocationFilter _locationFilter = _LocationFilter.all;

  String? get _token => AuthSession.current?.token.trim();

  @override
  void initState() {
    super.initState();
    _selectedBackend = _backend.kind;
    _hostController = TextEditingController(text: BackendRuntime.host);
    final session = AuthSession.current;
    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/');
      });
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!session.user.isAdmin) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Admin access required')));
        Navigator.pushReplacementNamed(context, '/home');
        return;
      }
      await _loadAdminData();
    });
  }

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  Future<void> _applyBackendSelection() async {
    final host = BackendRuntime.normalizeHostInput(_hostController.text);
    final next = BackendConfig.forKind(
      _selectedBackend,
      host: host,
      scheme: BackendRuntime.scheme,
    );
    BackendRuntime.setConfig(next);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Backend set to ${next.label} (${next.baseUrl})')),
    );
    Navigator.pushReplacementNamed(context, '/home');
  }

  Future<void> _loadAdminData() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'Login required. Please sign in again.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final employeesFuture = _api.listEmployees(bearerToken: token);
      final jobsFuture = _api.listJobs(bearerToken: token);
      final clientsFuture = _api.listClients(bearerToken: token);
      final locationsFuture = _api.listLocations(bearerToken: token);
      final results = await Future.wait([
        employeesFuture,
        jobsFuture,
        clientsFuture,
        locationsFuture,
      ]);
      final employees = results[0] as List<Employee>;
      final jobs = results[1] as List<Job>;
      final clients = results[2] as List<Client>;
      final locations = results[3] as List<Location>;

      if (!mounted) return;
      setState(() {
        _employees = employees;
        _jobs = jobs;
        _clients = clients;
        _locations = locations;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = userFacingError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _showCreateDialog() async {
    if (AppEnv.isDemoMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo mode: create/edit/delete actions are disabled'),
        ),
      );
      return;
    }

    final result = await showDialog<EmployeeCreateInput>(
      context: context,
      builder: (context) => const _EmployeeEditorDialog(),
    );

    if (result == null) return;

    try {
      final created = await _api.createEmployee(result, bearerToken: _token);
      await _loadAdminData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Employee created. Invitation email requested for ${created.email ?? result.email}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  Future<void> _showEditDialog(Employee employee) async {
    if (AppEnv.isDemoMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo mode: create/edit/delete actions are disabled'),
        ),
      );
      return;
    }
    final result = await showDialog<EmployeeUpdateInput>(
      context: context,
      builder: (context) => _EmployeeEditorDialog(
        name: employee.name,
        email: employee.email ?? '',
        phoneNumber: employee.phoneNumber ?? '',
        address: employee.address ?? '',
        city: employee.city ?? '',
        state: employee.state ?? '',
        zipCode: employee.zipCode ?? '',
        isCreate: false,
      ),
    );

    if (result == null) return;

    try {
      await _api.updateEmployee(employee.id, result, bearerToken: _token);
      await _loadAdminData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Employee updated')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  Future<void> _delete(Employee employee) async {
    if (AppEnv.isDemoMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo mode: create/edit/delete actions are disabled'),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete employee'),
        content: Text('Delete ${employee.employeeNumber} - ${employee.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final message = await _api.deleteEmployee(
        employee.id,
        bearerToken: _token,
      );
      await _loadAdminData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  Future<void> _showCreateClientDialog() async {
    if (AppEnv.isDemoMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo mode: create/edit/delete actions are disabled'),
        ),
      );
      return;
    }

    final result = await showDialog<ClientCreateInput>(
      context: context,
      builder: (context) => const _ClientEditorDialog(),
    );
    if (result == null) return;

    try {
      await _api.createClient(result, bearerToken: _token);
      await _loadAdminData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Client created')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  Future<void> _showEditClientDialog(Client client) async {
    if (AppEnv.isDemoMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo mode: create/edit/delete actions are disabled'),
        ),
      );
      return;
    }

    final result = await showDialog<ClientUpdateInput>(
      context: context,
      builder: (context) => _ClientEditorDialog(
        isCreate: false,
        name: client.name,
        email: client.email ?? '',
        phoneNumber: client.phoneNumber ?? '',
        address: client.address ?? '',
        city: client.city ?? '',
        state: client.state ?? '',
        zipCode: client.zipCode ?? '',
      ),
    );
    if (result == null) return;

    try {
      await _api.updateClient(client.id, result, bearerToken: _token);
      await _loadAdminData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Client updated')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  Future<void> _deleteClient(Client client) async {
    if (AppEnv.isDemoMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo mode: create/edit/delete actions are disabled'),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete client'),
        content: Text('Delete ${client.clientNumber} - ${client.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final message = await _api.deleteClient(client.id, bearerToken: _token);
      await _loadAdminData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  Future<void> _showCreateLocationDialog() async {
    if (AppEnv.isDemoMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo mode: create/edit/delete actions are disabled'),
        ),
      );
      return;
    }
    final result = await showDialog<LocationCreateInput>(
      context: context,
      builder: (context) => _LocationEditorDialog(clients: _clients),
    );
    if (result == null) return;

    try {
      await _api.createLocation(result, bearerToken: _token);
      await _loadAdminData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Location created')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  Future<void> _showEditLocationDialog(Location location) async {
    if (AppEnv.isDemoMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo mode: create/edit/delete actions are disabled'),
        ),
      );
      return;
    }
    final result = await showDialog<LocationUpdateInput>(
      context: context,
      builder: (context) => _LocationEditorDialog(
        clients: _clients,
        isCreate: false,
        clientId: location.clientId,
        type: location.type,
        address: location.address ?? '',
        city: location.city ?? '',
        state: location.state ?? '',
        zipCode: location.zipCode ?? '',
      ),
    );
    if (result == null) return;

    try {
      await _api.updateLocation(location.id, result, bearerToken: _token);
      await _loadAdminData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Location updated')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  Future<void> _deleteLocation(Location location) async {
    if (AppEnv.isDemoMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo mode: create/edit/delete actions are disabled'),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete location'),
        content: Text(
          'Delete ${location.locationNumber} (client ${location.clientId})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final message = await _api.deleteLocation(
        location.id,
        bearerToken: _token,
      );
      await _loadAdminData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  List<Employee> get _filteredEmployees {
    return _employees.where((employee) {
      final status = employee.status.trim().toLowerCase();
      switch (_employeeFilter) {
        case _EmployeeFilter.active:
          return status == 'active';
        case _EmployeeFilter.inactive:
          return status != 'active';
        case _EmployeeFilter.all:
          return true;
      }
    }).toList();
  }

  List<Client> get _filteredClients {
    return _clients.where((client) {
      final status = client.status.trim().toLowerCase();
      switch (_clientFilter) {
        case _ClientFilter.active:
          return status == 'active';
        case _ClientFilter.inactive:
          return status != 'active';
        case _ClientFilter.all:
          return true;
      }
    }).toList();
  }

  List<Location> get _filteredLocations {
    return _locations.where((location) {
      final status = location.status.trim().toLowerCase();
      switch (_locationFilter) {
        case _LocationFilter.active:
          return status == 'active';
        case _LocationFilter.inactive:
          return status != 'active';
        case _LocationFilter.all:
          return true;
      }
    }).toList();
  }

  int get _totalPendingJobs =>
      _jobs.where((job) => job.status.trim().toLowerCase() == 'pending').length;

  int get _totalAssignedJobs => _jobs
      .where((job) => job.status.trim().toLowerCase() == 'assigned')
      .length;

  int get _totalInProgressJobs => _jobs
      .where((job) => job.status.trim().toLowerCase() == 'in_progress')
      .length;

  int get _totalCompletedJobs => _jobs
      .where((job) => job.status.trim().toLowerCase() == 'completed')
      .length;

  int get _totalOverdueJobs {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    return _jobs.where((job) {
      final status = job.status.trim().toLowerCase();
      if (status == 'completed' ||
          status == 'canceled' ||
          status == 'cancelled') {
        return false;
      }
      final parsed = parseFlexibleDate(job.scheduledDate);
      if (parsed == null) return false;
      return parsed.isBefore(startOfToday);
    }).length;
  }

  Widget _metricTile({
    required String label,
    required String value,
    required Color bg,
    required Color fg,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.w700, color: fg),
          ),
          Text(value, style: TextStyle(color: fg)),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    Widget navTile({
      required _AdminSection section,
      required IconData icon,
      required String title,
    }) {
      final selected = _selectedSection == section;
      return ListTile(
        leading: Icon(icon),
        title: Text(title),
        selected: selected,
        onTap: () => setState(() => _selectedSection = section),
      );
    }

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Admin Workspace',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          navTile(
            section: _AdminSection.jobs,
            icon: Icons.work_outline,
            title: 'Jobs',
          ),
          navTile(
            section: _AdminSection.cleaningProfiles,
            icon: Icons.checklist_rtl_outlined,
            title: 'Cleaning Profiles',
          ),
          navTile(
            section: _AdminSection.clients,
            icon: Icons.business_outlined,
            title: 'Clients',
          ),
          navTile(
            section: _AdminSection.employees,
            icon: Icons.badge_outlined,
            title: 'Employees',
          ),
          navTile(
            section: _AdminSection.locations,
            icon: Icons.location_on_outlined,
            title: 'Locations',
          ),
          navTile(
            section: _AdminSection.reports,
            icon: Icons.assessment_outlined,
            title: 'Reports',
          ),
          const Divider(height: 24),
          navTile(
            section: _AdminSection.dashboard,
            icon: Icons.dashboard_outlined,
            title: 'Overview Dashboard',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Theme.of(context).hintColor)),
        ],
      ),
    );
  }

  Widget _buildDashboardSection() {
    final activeEmployees = _employees
        .where((e) => e.status.trim().toLowerCase() == 'active')
        .length;
    return ListView(
      children: [
        _buildSectionHeader(
          'Operations Dashboard',
          'Snapshot across all employees and all jobs.',
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _metricTile(
              label: 'Pending',
              value: _totalPendingJobs.toString(),
              icon: Icons.pending_actions,
              bg: const Color.fromRGBO(255, 249, 224, 1),
              fg: const Color.fromRGBO(138, 92, 8, 1),
            ),
            _metricTile(
              label: 'Assigned',
              value: _totalAssignedJobs.toString(),
              icon: Icons.assignment_outlined,
              bg: const Color.fromRGBO(255, 249, 224, 1),
              fg: const Color.fromRGBO(138, 92, 8, 1),
            ),
            _metricTile(
              label: 'In Progress',
              value: _totalInProgressJobs.toString(),
              icon: Icons.timelapse_outlined,
              bg: const Color.fromRGBO(233, 246, 241, 1),
              fg: const Color.fromRGBO(29, 102, 76, 1),
            ),
            _metricTile(
              label: 'Completed',
              value: _totalCompletedJobs.toString(),
              icon: Icons.task_alt,
              bg: const Color.fromRGBO(227, 241, 233, 1),
              fg: const Color.fromRGBO(22, 89, 56, 1),
            ),
            _metricTile(
              label: 'Overdue',
              value: _totalOverdueJobs.toString(),
              icon: Icons.warning_amber_outlined,
              bg: const Color.fromRGBO(255, 232, 238, 1),
              fg: const Color.fromRGBO(156, 42, 74, 1),
            ),
            _metricTile(
              label: 'Employees',
              value: '${_employees.length} total ($activeEmployees active)',
              icon: Icons.groups_outlined,
              bg: const Color.fromRGBO(236, 244, 240, 1),
              fg: const Color.fromRGBO(45, 87, 73, 1),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Suggested next scaffolds',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '1. Add per-employee utilization chart (assigned vs completed in period).',
                  style: TextStyle(color: Theme.of(context).hintColor),
                ),
                Text(
                  '2. Add quick late-job list with drill-down into Jobs workspace.',
                  style: TextStyle(color: Theme.of(context).hintColor),
                ),
                Text(
                  '3. Add report export stubs (CSV/PDF) in Reports section.',
                  style: TextStyle(color: Theme.of(context).hintColor),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeesSection() {
    final rows = _filteredEmployees;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Employees',
          'Create, edit, delete, and filter employees by status.',
        ),
        Row(
          children: [
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _employeeFilter == _EmployeeFilter.all,
                  onSelected: (_) =>
                      setState(() => _employeeFilter = _EmployeeFilter.all),
                ),
                ChoiceChip(
                  label: const Text('Active'),
                  selected: _employeeFilter == _EmployeeFilter.active,
                  onSelected: (_) =>
                      setState(() => _employeeFilter = _EmployeeFilter.active),
                ),
                ChoiceChip(
                  label: const Text('Inactive'),
                  selected: _employeeFilter == _EmployeeFilter.inactive,
                  onSelected: (_) => setState(
                    () => _employeeFilter = _EmployeeFilter.inactive,
                  ),
                ),
              ],
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: AppEnv.isDemoMode ? null : _showCreateDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('Create Employee'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Employee #')),
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('Phone')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: rows
                      .map(
                        (employee) => DataRow(
                          cells: [
                            DataCell(Text(employee.employeeNumber)),
                            DataCell(Text(employee.name)),
                            DataCell(Text(employee.status)),
                            DataCell(Text(employee.email ?? '—')),
                            DataCell(Text(employee.phoneNumber ?? '—')),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    tooltip: 'Edit',
                                    onPressed: AppEnv.isDemoMode
                                        ? null
                                        : () => _showEditDialog(employee),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    tooltip: 'Delete',
                                    onPressed: AppEnv.isDemoMode
                                        ? null
                                        : () => _delete(employee),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClientsSection() {
    final rows = _filteredClients;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Clients',
          'Create, edit, delete, and filter clients by status.',
        ),
        Row(
          children: [
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _clientFilter == _ClientFilter.all,
                  onSelected: (_) =>
                      setState(() => _clientFilter = _ClientFilter.all),
                ),
                ChoiceChip(
                  label: const Text('Active'),
                  selected: _clientFilter == _ClientFilter.active,
                  onSelected: (_) =>
                      setState(() => _clientFilter = _ClientFilter.active),
                ),
                ChoiceChip(
                  label: const Text('Inactive'),
                  selected: _clientFilter == _ClientFilter.inactive,
                  onSelected: (_) =>
                      setState(() => _clientFilter = _ClientFilter.inactive),
                ),
              ],
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: AppEnv.isDemoMode ? null : _showCreateClientDialog,
              icon: const Icon(Icons.business),
              label: const Text('Create Client'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Client #')),
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('Phone')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: rows
                      .map(
                        (client) => DataRow(
                          cells: [
                            DataCell(Text(client.clientNumber)),
                            DataCell(Text(client.name)),
                            DataCell(Text(client.status)),
                            DataCell(Text(client.email ?? '—')),
                            DataCell(Text(client.phoneNumber ?? '—')),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    tooltip: 'Edit',
                                    onPressed: AppEnv.isDemoMode
                                        ? null
                                        : () => _showEditClientDialog(client),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    tooltip: 'Delete',
                                    onPressed: AppEnv.isDemoMode
                                        ? null
                                        : () => _deleteClient(client),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationsSection() {
    final rows = _filteredLocations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Locations',
          'Create, edit, delete, and filter locations by status.',
        ),
        Row(
          children: [
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _locationFilter == _LocationFilter.all,
                  onSelected: (_) =>
                      setState(() => _locationFilter = _LocationFilter.all),
                ),
                ChoiceChip(
                  label: const Text('Active'),
                  selected: _locationFilter == _LocationFilter.active,
                  onSelected: (_) =>
                      setState(() => _locationFilter = _LocationFilter.active),
                ),
                ChoiceChip(
                  label: const Text('Inactive'),
                  selected: _locationFilter == _LocationFilter.inactive,
                  onSelected: (_) => setState(
                    () => _locationFilter = _LocationFilter.inactive,
                  ),
                ),
              ],
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: AppEnv.isDemoMode ? null : _showCreateLocationDialog,
              icon: const Icon(Icons.add_location_alt),
              label: const Text('Create Location'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Location #')),
                    DataColumn(label: Text('Client ID')),
                    DataColumn(label: Text('Type')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Address')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: rows
                      .map(
                        (location) => DataRow(
                          cells: [
                            DataCell(Text(location.locationNumber)),
                            DataCell(Text(location.clientId.toString())),
                            DataCell(Text(location.type)),
                            DataCell(Text(location.status)),
                            DataCell(
                              Text(
                                [
                                  location.address ?? '',
                                  location.city ?? '',
                                  location.state ?? '',
                                  location.zipCode ?? '',
                                ].where((e) => e.trim().isNotEmpty).join(', '),
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    tooltip: 'Edit',
                                    onPressed: AppEnv.isDemoMode
                                        ? null
                                        : () =>
                                              _showEditLocationDialog(location),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    tooltip: 'Delete',
                                    onPressed: AppEnv.isDemoMode
                                        ? null
                                        : () => _deleteLocation(location),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCrudScaffoldSection({
    required String title,
    required String subtitle,
    required List<Widget> actions,
    required String bodyText,
  }) {
    return ListView(
      children: [
        _buildSectionHeader(title, subtitle),
        Wrap(spacing: 10, runSpacing: 10, children: actions),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(bodyText),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionContent() {
    switch (_selectedSection) {
      case _AdminSection.dashboard:
        return _buildDashboardSection();
      case _AdminSection.employees:
        return _buildEmployeesSection();
      case _AdminSection.jobs:
        return _buildCrudScaffoldSection(
          title: 'Jobs',
          subtitle:
              'Create jobs, attach locations, assign cleaning profiles, and manage assignments.',
          actions: [
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/jobs'),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open Jobs Route'),
            ),
          ],
          bodyText:
              'Scaffold ready. Next step: inline Jobs CRUD table and create modal with profile/location pickers.',
        );
      case _AdminSection.cleaningProfiles:
        return _buildCrudScaffoldSection(
          title: 'Cleaning Profiles',
          subtitle: 'Create profiles and attach task definitions/rules.',
          actions: [
            FilledButton.icon(
              onPressed: null,
              icon: Icon(Icons.add_task),
              label: Text('Create Profile (Coming Soon)'),
            ),
            OutlinedButton.icon(
              onPressed: null,
              icon: Icon(Icons.rule),
              label: Text('Manage Rules (Coming Soon)'),
            ),
          ],
          bodyText:
              'Placeholder: this will host profile CRUD and task/rule builder incrementally.',
        );
      case _AdminSection.clients:
        return _buildClientsSection();
      case _AdminSection.locations:
        return _buildLocationsSection();
      case _AdminSection.reports:
        return _buildCrudScaffoldSection(
          title: 'Reports',
          subtitle: 'Reporting workspace scaffold.',
          actions: [
            FilledButton.icon(
              onPressed: null,
              icon: Icon(Icons.summarize),
              label: Text('Generate Report (Coming Soon)'),
            ),
          ],
          bodyText:
              'Placeholder: report templates for operations, payroll windows, and client service summaries.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anderson Express Cleaning Service'),
        bottom: const BackendBanner(),
        actions: [
          IconButton(
            onPressed: () {
              AuthSession.clear();
              Navigator.pushReplacementNamed(context, '/');
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
          IconButton(
            onPressed: _loading ? null : _loadAdminData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (BackendRuntime.allowBackendOverride) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _hostController,
                            decoration: const InputDecoration(
                              labelText: 'Backend Host',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _applyBackendSelection,
                          icon: const Icon(Icons.check),
                          label: const Text('Apply'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (AppEnv.isDemoMode) ...[
                    const DemoModeNotice(
                      message:
                          'Demo mode is enabled: destructive actions are disabled in preview.',
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _buildSectionContent(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeEditorDialog extends StatefulWidget {
  const _EmployeeEditorDialog({
    this.name = '',
    this.email = '',
    this.phoneNumber = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.zipCode = '',
    this.isCreate = true,
  });

  final String name;
  final String email;
  final String phoneNumber;
  final String address;
  final String city;
  final String state;
  final String zipCode;
  final bool isCreate;

  @override
  State<_EmployeeEditorDialog> createState() => _EmployeeEditorDialogState();
}

class _EmployeeEditorDialogState extends State<_EmployeeEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _zipCode;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.name);
    _email = TextEditingController(text: widget.email);
    _phone = TextEditingController(text: widget.phoneNumber);
    _address = TextEditingController(text: widget.address);
    _city = TextEditingController(text: widget.city);
    _state = TextEditingController(text: widget.state);
    _zipCode = TextEditingController(text: widget.zipCode);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _zipCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isCreate ? 'Create Employee' : 'Edit Employee'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_name, 'Name'),
              const SizedBox(height: 10),
              _field(_email, 'Email'),
              const SizedBox(height: 10),
              _field(_phone, 'Phone'),
              const SizedBox(height: 10),
              _field(_address, 'Address'),
              const SizedBox(height: 10),
              _field(_city, 'City'),
              const SizedBox(height: 10),
              _field(_state, 'State'),
              const SizedBox(height: 10),
              _field(_zipCode, 'Zip Code'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (widget.isCreate) {
              if (_name.text.trim().isEmpty || _email.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(
                context,
                EmployeeCreateInput(
                  name: _name.text.trim(),
                  email: _email.text.trim(),
                  phoneNumber: _nullable(_phone.text),
                  address: _nullable(_address.text),
                  city: _nullable(_city.text),
                  state: _nullable(_state.text),
                  zipCode: _nullable(_zipCode.text),
                ),
              );
            } else {
              Navigator.pop(
                context,
                EmployeeUpdateInput(
                  name: _nullable(_name.text),
                  email: _nullable(_email.text),
                  phoneNumber: _nullable(_phone.text),
                  address: _nullable(_address.text),
                  city: _nullable(_city.text),
                  state: _nullable(_state.text),
                  zipCode: _nullable(_zipCode.text),
                ),
              );
            }
          },
          child: Text(widget.isCreate ? 'Create' : 'Save'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _ClientEditorDialog extends StatefulWidget {
  const _ClientEditorDialog({
    this.name = '',
    this.email = '',
    this.phoneNumber = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.zipCode = '',
    this.isCreate = true,
  });

  final String name;
  final String email;
  final String phoneNumber;
  final String address;
  final String city;
  final String state;
  final String zipCode;
  final bool isCreate;

  @override
  State<_ClientEditorDialog> createState() => _ClientEditorDialogState();
}

class _ClientEditorDialogState extends State<_ClientEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _zipCode;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.name);
    _email = TextEditingController(text: widget.email);
    _phone = TextEditingController(text: widget.phoneNumber);
    _address = TextEditingController(text: widget.address);
    _city = TextEditingController(text: widget.city);
    _state = TextEditingController(text: widget.state);
    _zipCode = TextEditingController(text: widget.zipCode);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _zipCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isCreate ? 'Create Client' : 'Edit Client'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_name, 'Name'),
              const SizedBox(height: 10),
              _field(_email, 'Email'),
              const SizedBox(height: 10),
              _field(_phone, 'Phone'),
              const SizedBox(height: 10),
              _field(_address, 'Address'),
              const SizedBox(height: 10),
              _field(_city, 'City'),
              const SizedBox(height: 10),
              _field(_state, 'State'),
              const SizedBox(height: 10),
              _field(_zipCode, 'Zip Code'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (widget.isCreate) {
              if (_name.text.trim().isEmpty || _email.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(
                context,
                ClientCreateInput(
                  name: _name.text.trim(),
                  email: _email.text.trim(),
                  phoneNumber: _nullable(_phone.text),
                  address: _nullable(_address.text),
                  city: _nullable(_city.text),
                  state: _nullable(_state.text),
                  zipCode: _nullable(_zipCode.text),
                ),
              );
            } else {
              Navigator.pop(
                context,
                ClientUpdateInput(
                  name: _nullable(_name.text),
                  email: _nullable(_email.text),
                  phoneNumber: _nullable(_phone.text),
                  address: _nullable(_address.text),
                  city: _nullable(_city.text),
                  state: _nullable(_state.text),
                  zipCode: _nullable(_zipCode.text),
                ),
              );
            }
          },
          child: Text(widget.isCreate ? 'Create' : 'Save'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _LocationEditorDialog extends StatefulWidget {
  const _LocationEditorDialog({
    required this.clients,
    this.clientId,
    this.type = 'residential',
    this.address = '',
    this.city = '',
    this.state = '',
    this.zipCode = '',
    this.isCreate = true,
  });

  final List<Client> clients;
  final int? clientId;
  final String type;
  final String address;
  final String city;
  final String state;
  final String zipCode;
  final bool isCreate;

  @override
  State<_LocationEditorDialog> createState() => _LocationEditorDialogState();
}

class _LocationEditorDialogState extends State<_LocationEditorDialog> {
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _zipCode;
  late String _type;
  int? _selectedClientId;

  @override
  void initState() {
    super.initState();
    _address = TextEditingController(text: widget.address);
    _city = TextEditingController(text: widget.city);
    _state = TextEditingController(text: widget.state);
    _zipCode = TextEditingController(text: widget.zipCode);
    _type = widget.type.toLowerCase();
    _selectedClientId =
        widget.clientId ??
        (widget.clients.isNotEmpty
            ? int.tryParse(widget.clients.first.id)
            : null);
  }

  @override
  void dispose() {
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _zipCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isCreate ? 'Create Location' : 'Edit Location'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isCreate)
                DropdownButtonFormField<int>(
                  initialValue: _selectedClientId,
                  decoration: const InputDecoration(
                    labelText: 'Client',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.clients
                      .map(
                        (client) => DropdownMenuItem<int>(
                          value: int.tryParse(client.id),
                          child: Text(
                            '${client.clientNumber} • ${client.name}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedClientId = value),
                ),
              if (widget.isCreate) const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'residential',
                    child: Text('Residential'),
                  ),
                  DropdownMenuItem(
                    value: 'commercial',
                    child: Text('Commercial'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _type = value);
                },
              ),
              const SizedBox(height: 10),
              _field(_address, 'Address'),
              const SizedBox(height: 10),
              _field(_city, 'City'),
              const SizedBox(height: 10),
              _field(_state, 'State'),
              const SizedBox(height: 10),
              _field(_zipCode, 'Zip Code'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (widget.isCreate) {
              if (_selectedClientId == null) return;
              Navigator.pop(
                context,
                LocationCreateInput(
                  type: _type,
                  clientId: _selectedClientId!,
                  address: _nullable(_address.text),
                  city: _nullable(_city.text),
                  state: _nullable(_state.text),
                  zipCode: _nullable(_zipCode.text),
                ),
              );
            } else {
              Navigator.pop(
                context,
                LocationUpdateInput(
                  type: _type,
                  address: _nullable(_address.text),
                  city: _nullable(_city.text),
                  state: _nullable(_state.text),
                  zipCode: _nullable(_zipCode.text),
                ),
              );
            }
          },
          child: Text(widget.isCreate ? 'Create' : 'Save'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
