
import 'package:flutter/material.dart';

import '../models/backend_config.dart';
import '../models/cleaning_profile.dart';
import '../models/cleaning_request.dart';
import '../models/client.dart';
import '../models/employee.dart';
import '../models/job.dart';
import '../models/job_assignment.dart';
import '../models/location.dart';
import '../models/profile_task.dart';
import '../models/task_definition.dart';
import '../models/task_rule.dart';
import '../services/api_service.dart';
import '../services/app_env.dart';
import '../services/auth_session.dart';
import '../services/backend_runtime.dart';
import '../theme/crud_modal_theme.dart';
import '../utils/date_format.dart';
import '../utils/error_text.dart';
import '../widgets/admin/dialogs/cleaning_profile_editor_dialog.dart';
import '../widgets/admin/dialogs/client_editor_dialog.dart';
import '../widgets/admin/dialogs/employee_editor_dialog.dart';
import '../widgets/admin/dialogs/job_editor_dialog.dart';
import '../widgets/admin/dialogs/location_editor_dialog.dart';
import '../widgets/admin/dialogs/profile_task_editor_dialog.dart';
import '../widgets/admin/dialogs/task_definition_editor_dialog.dart';
import '../widgets/admin/dialogs/task_rule_editor_dialog.dart';
import '../widgets/admin/admin_sidebar.dart';
import '../widgets/admin/sections/cleaning_profiles_section.dart';
import '../widgets/admin/sections/dashboard_section.dart';
import '../widgets/admin/sections/management_section.dart';
import '../utils/dialog_utils.dart';
import '../widgets/backend_banner.dart';
import '../widgets/brand_app_bar_title.dart';
import '../widgets/demo_mode_notice.dart';
import '../widgets/profile_menu_button.dart';
import '../widgets/theme_toggle_button.dart';
import '../utils/navigation_extensions.dart';



enum _EmployeeFilter { all, active, invited }

enum _ClientFilter { all, active, inactive }

enum _LocationFilter { all, active, inactive }

enum _JobFilter { all, active }



class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  static const String _defaultEmployeePhotoAsset =
      '/assets/images/profiles/employee_default.png';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late BackendKind _selectedBackend;
  late final TextEditingController _hostController;

  BackendConfig get _backend => BackendRuntime.config;
  ApiService get _api => ApiService();

  bool _loading = false;
  bool _sidebarCollapsed = false;
  String? _error;
  List<Employee> _employees = const [];
  List<Job> _jobs = const [];
  List<Client> _clients = const [];
  List<Location> _locations = const [];
  List<CleaningProfile> _cleaningProfiles = const [];
  List<CleaningRequest> _cleaningRequests = const [];
  List<TaskDefinition> _taskDefinitions = const [];
  List<TaskRule> _taskRules = const [];
  List<ProfileTask> _selectedProfileTasks = const [];
  Map<String, List<String>> _jobAssignments = {}; // jobId → employee names
  AdminSection _selectedSection = AdminSection.dashboard;
  ManagementModel _managementModel = ManagementModel.jobs;
  bool _activeOnlyFilter = true;
  final _EmployeeFilter _employeeFilter = _EmployeeFilter.active;
  final _ClientFilter _clientFilter = _ClientFilter.active;
  final _LocationFilter _locationFilter = _LocationFilter.active;
  _JobFilter _jobFilter = _JobFilter.all;
  String _jobClientSearch = '';
  String _employeeSearch = '';
  String _clientSearch = '';
  String _locationSearch = '';
  int? _jobsSortColumnIndex;
  bool _jobsSortAscending = true;
  int? _clientsSortColumnIndex;
  bool _clientsSortAscending = true;
  DateTimeRange _jobDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now().add(const Duration(days: 30)),
  );
  CleaningRequestFilter _cleaningRequestFilter = CleaningRequestFilter.open;
  String? _selectedCleaningProfileId;
  bool _loadingProfileTasks = false;

  String? get _token => AuthSession.current?.token.trim();

  String _formatCoordinateStatus(double? latitude, double? longitude) {
    if (latitude != null && longitude != null) {
      return 'Coordinates saved (${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)})';
    }
    return 'Coordinates unavailable. Check address details.';
  }

  Future<void> _showDemoCreateDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Theme(
        data: buildCrudModalTheme(context),
        child: AlertDialog(
          title: Text(
            title,
            style: TextStyle(
              color: crudModalTitleColor(context),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    );
  }


  @override
  void initState() {
    super.initState();
    _selectedBackend = _backend.kind;
    _hostController = TextEditingController(text: BackendRuntime.host);
    final session = AuthSession.current;
    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.navigateToLogin();
      });
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!session.user.isAdmin) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Admin access required')));
        context.navigateToHome();
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
    context.navigateToAdmin();
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
      final employeesFuture = _api.listEmployees(
        employeeStatus: const [
          'active',
          'invited',
          'inactive',
          'resigned',
          'deleted',
        ],
        bearerToken: token,
      );
      final jobsFuture = _api.listJobs(bearerToken: token);
      final clientsFuture = _api.listClients(bearerToken: token);
      final locationsFuture = _api.listLocations(bearerToken: token);
      final profilesFuture = _api.listCleaningProfiles(bearerToken: token);
      final cleaningRequestsFuture = _api.listCleaningRequests(
        bearerToken: token,
      );
      final taskDefsFuture = _api.listTaskDefinitions(bearerToken: token);
      final taskRulesFuture = _api.listTaskRules(bearerToken: token);
      final results = await Future.wait([
        employeesFuture,
        jobsFuture,
        clientsFuture,
        locationsFuture,
        profilesFuture,
        cleaningRequestsFuture,
        taskDefsFuture,
        taskRulesFuture,
      ]);
      final employees = results[0] as List<Employee>;
      final jobs = results[1] as List<Job>;
      final clients = results[2] as List<Client>;
      final locations = results[3] as List<Location>;
      final profiles = results[4] as List<CleaningProfile>;
      final cleaningRequests = results[5] as List<CleaningRequest>;
      final taskDefinitions = results[6] as List<TaskDefinition>;
      final taskRules = results[7] as List<TaskRule>;
      
      // Fetch assignments for all jobs
      final allAssignments = <JobAssignment>[];
      for (final job in jobs) {
        try {
          final assignments = await _api.listJobAssignments(
            job.id,
            bearerToken: token,
          );
          allAssignments.addAll(assignments);
        } catch (e) {
          // Silently continue if assignment fetch fails for a job
          continue;
        }
      }
      final employeeNameById = <String, String>{};
      for (final employee in employees) {
        employeeNameById[employee.id] = employee.name;
      }
      
      // Build map of jobId → list of assigned employee names
      final assignmentsByJobId = <String, List<String>>{};
      for (final assignment in allAssignments) {
        // Include all assignments (active and inactive) for display purposes
        final jobId = assignment.jobId.toString();
        final employeeName = employeeNameById[assignment.employeeId] ?? 'Unknown';
        assignmentsByJobId.putIfAbsent(jobId, () => []).add(employeeName);
      }
      final previousSelected = _selectedCleaningProfileId;
      final nextSelected = profiles.any((p) => p.id == previousSelected)
          ? previousSelected
          : (profiles.isNotEmpty ? profiles.first.id : null);

      if (!mounted) return;
      setState(() {
        _employees = employees;
        _jobs = jobs;
        _clients = clients;
        _locations = locations;
        _cleaningProfiles = profiles;
        _cleaningRequests = cleaningRequests;
        _taskDefinitions = taskDefinitions;
        _taskRules = taskRules;
        _jobAssignments = assignmentsByJobId;
        _selectedCleaningProfileId = nextSelected;
        if (nextSelected == null) {
          _selectedProfileTasks = const [];
        }
      });
      if (nextSelected != null) {
        await _loadProfileTasks(nextSelected, setLoading: false);
      }
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
    final result = await showDialog<EmployeeCreateInput>(
      context: context,
      builder: (context) => const EmployeeEditorDialog(),
    );

    if (result == null) return;

    if (AppEnv.isDemoMode) {
      await _showDemoCreateDialog(
        title: 'Demo Employee Created',
        message:
            'Employee "${result.name}" was created in preview mode for walkthrough purposes. No database changes were made.',
      );
      return;
    }

    try {
      final payload = EmployeeCreateInput(
        name: result.name,
        email: result.email,
        accessLevel: result.accessLevel,
        phoneNumber: result.phoneNumber,
        address: result.address,
        city: result.city,
        state: result.state,
        zipCode: result.zipCode,
        photoUrl: (result.photoUrl == null || result.photoUrl!.trim().isEmpty)
            ? _defaultEmployeePhotoAsset
            : result.photoUrl,
        status: result.status,
      );
      final created = await _api.createEmployee(payload, bearerToken: _token);
      await _loadAdminData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Employee created. Invitation email requested for ${created.email ?? result.email}. ${_formatCoordinateStatus(created.latitude, created.longitude)}',
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
    final result = await showDialog<EmployeeUpdateInput>(
      context: context,
      builder: (context) => EmployeeEditorDialog(
        employeeToEdit: employee,
        onDelete: () => _deleteEmployee(employee),
        employeeNumber: employee.employeeNumber,
        status: employee.status,
        name: employee.name,
        email: employee.email ?? '',
        phoneNumber: employee.phoneNumber ?? '',
        address: employee.address ?? '',
        city: employee.city ?? '',
        state: employee.state ?? '',
        zipCode: employee.zipCode ?? '',
        photoUrl: employee.photoUrl ?? '',
        isCreate: false,
      ),
    );

    if (result == null) return;

    if (AppEnv.isDemoMode) {
      await _showDemoCreateDialog(
        title: 'Demo Employee Updated',
        message:
            'Employee "${employee.name}" was updated in preview walkthrough mode. No database changes were made.',
      );
      return;
    }

    try {
      final updated = await _api.updateEmployee(
        employee.id,
        result,
        bearerToken: _token,
      );
      await _loadAdminData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Employee updated. ${_formatCoordinateStatus(updated.latitude, updated.longitude)}',
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

  Future<void> _showCreateClientDialog() async {
    final result = await showDialog<ClientCreateInput>(
      context: context,
      builder: (context) => const ClientEditorDialog(),
    );
    if (result == null) return;

    if (AppEnv.isDemoMode) {
      await _showDemoCreateDialog(
        title: 'Demo Client Created',
        message:
            'Client "${result.name}" was created in preview mode for walkthrough purposes. No database changes were made.',
      );
      return;
    }

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
    final result = await showDialog<ClientUpdateInput>(
      context: context,
      builder: (context) => ClientEditorDialog(
        clientToEdit: client,
        onDelete: () => _deleteClient(client),
        isCreate: false,
        name: client.name,
        status: client.status,
        email: client.email ?? '',
        phoneNumber: client.phoneNumber ?? '',
        address: client.address ?? '',
        city: client.city ?? '',
        state: client.state ?? '',
        zipCode: client.zipCode ?? '',
        preferredContactMethod: client.preferredContactMethod ?? '',
        preferredContactWindow: client.preferredContactWindow ?? '',
        serviceNotes: client.serviceNotes ?? '',
      ),
    );
    if (result == null) return;

    if (AppEnv.isDemoMode) {
      await _showDemoCreateDialog(
        title: 'Demo Client Updated',
        message:
            'Client "${client.name}" was updated in preview walkthrough mode. No database changes were made.',
      );
      return;
    }

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

  Future<void> _deleteEmployee(Employee emp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Employee'),
        content: Text('Delete ${emp.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _api.deleteEmployee(emp.id);
      await _loadAdminData();
    }
  }

  Future<void> _deleteClient(Client client) async {
    final confirmed = await showDeleteConfirmationDialog(
      context,
      itemType: 'client',
      itemName: '${client.clientNumber} - ${client.name}',
    );
    if (!confirmed) return;

    if (AppEnv.isDemoMode) {
      await _showDemoCreateDialog(
        title: 'Demo Client Deleted',
        message:
            'Client "${client.name}" was removed in preview walkthrough mode. No database changes were made.',
      );
      return;
    }

    try {
      final message = await _api.deleteClient(client.id, bearerToken: _token);
      await _loadAdminData();
      if (!mounted) return;
      showSuccessSnackBar(context, message);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  Future<void> _showCreateLocationDialog() async {
    final result = await showDialog<LocationCreateInput>(
      context: context,
      builder: (context) => LocationEditorDialog(clients: _clients),
    );
    if (result == null) return;

    if (AppEnv.isDemoMode) {
      final address = [
        result.address ?? '',
        result.city ?? '',
        result.state ?? '',
      ].where((p) => p.trim().isNotEmpty).join(', ');
      await _showDemoCreateDialog(
        title: 'Demo Location Created',
        message:
            'Location "${result.type}"${address.isNotEmpty ? ' at $address' : ''} was created in preview mode for walkthrough purposes. No database changes were made.',
      );
      return;
    }

    try {
      final created = await _api.createLocation(result, bearerToken: _token);
      await _loadAdminData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Location created. ${_formatCoordinateStatus(created.latitude, created.longitude)}',
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

  Future<void> _showEditLocationDialog(Location location) async {
    final result = await showDialog<LocationUpdateInput>(
      context: context,
      builder: (context) => LocationEditorDialog(
        clients: _clients,
        locationToEdit: location,
        onDelete: () => _deleteLocation(location),
        isCreate: false,
        clientId: location.clientId,
        status: location.status,
        type: location.type,
        photoUrl: location.photoUrl ?? '',
        address: location.address ?? '',
        city: location.city ?? '',
        state: location.state ?? '',
        zipCode: location.zipCode ?? '',
      ),
    );
    if (result == null) return;

    if (AppEnv.isDemoMode) {
      await _showDemoCreateDialog(
        title: 'Demo Location Updated',
        message:
            'Location "${location.locationNumber}" was updated in preview walkthrough mode. No database changes were made.',
      );
      return;
    }

    try {
      final updated = await _api.updateLocation(
        location.id,
        result,
        bearerToken: _token,
      );
      await _loadAdminData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Location updated. ${_formatCoordinateStatus(updated.latitude, updated.longitude)}',
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

  Future<void> _deleteLocation(Location location) async {
    final confirmed = await showDeleteConfirmationDialog(
      context,
      itemType: 'location',
      itemName: '${location.locationNumber} (client ${location.clientId})',
    );
    if (!confirmed) return;

    if (AppEnv.isDemoMode) {
      await _showDemoCreateDialog(
        title: 'Demo Location Deleted',
        message:
            'Location "${location.locationNumber}" was removed in preview walkthrough mode. No database changes were made.',
      );
      return;
    }

    try {
      final message = await _api.deleteLocation(
        location.id,
        bearerToken: _token,
      );
      await _loadAdminData();
      if (!mounted) return;
      showSuccessSnackBar(context, message);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  Future<void> _showCreateJobDialog() async {
    final result = await showDialog<JobEditorFormData>(
      context: context,
      builder: (context) => JobEditorDialog(
        isCreate: true,
        clients: _activeClients,
        locations: _activeLocations,
        cleaners: _activeCleaners,
      ),
    );
    if (result == null) return;

    if (AppEnv.isDemoMode) {
      await _showDemoCreateDialog(
        title: 'Demo Job Created',
        message:
            'Job creation flow completed in preview walkthrough mode. No database changes were made.',
      );
      return;
    }

    final profileId = _profileIdForLocation(result.locationId);
    if (profileId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No cleaning profile found for selected location. Create a cleaning profile first.',
          ),
        ),
      );
      return;
    }

    try {
      final created = await _api.createJob(
        JobCreateInput(
          profileId: profileId,
          locationId: result.locationId,
          scheduledDate: result.scheduledDate,
          scheduledStartAt: result.scheduledStartAt,
          estimatedDurationMinutes: result.estimatedDurationMinutes,
          actualDurationMinutes: result.actualDurationMinutes,
        ),
        bearerToken: _token,
      );

      if (result.cleanerEmployeeId != null) {
        await _api.createJobAssignment(
          created.id,
          JobAssignmentCreateInput(employeeId: result.cleanerEmployeeId!),
          bearerToken: _token,
        );
        await _api.updateJob(
          created.id,
          JobUpdateInput(
            profileId: profileId,
            scheduledDate: result.scheduledDate,
            scheduledStartAt: result.scheduledStartAt,
            status: 'assigned',
            estimatedDurationMinutes: result.estimatedDurationMinutes,
          ),
          bearerToken: _token,
        );
      }

      await _loadAdminData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Job created')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  Future<void> _showEditJobDialog(Job job) async {
    final activeLocations = _activeLocations;
    String? initialCleanerEmployeeId;
    try {
      final existingAssignments = await _api.listJobAssignments(
        job.id,
        bearerToken: _token,
      );
      for (final assignment in existingAssignments) {
        if (assignment.isActive) {
          initialCleanerEmployeeId = assignment.employeeId;
          break;
        }
      }
    } catch (_) {}
    if (!mounted) return;
    int? initialClientId;
    for (final location in activeLocations) {
      final locationId = int.tryParse(location.id);
      if (locationId == job.locationId) {
        initialClientId = location.clientId;
        break;
      }
    }
    final result = await showDialog<JobEditorFormData>(
      context: context,
      builder: (context) => JobEditorDialog(
        isCreate: false,
        clients: _activeClients,
        locations: activeLocations,
        cleaners: _activeCleaners,
        jobToEdit: job,
        onDelete: () => _deleteJob(job),
        initialClientId: initialClientId,
        initialLocationId: job.locationId,
        initialScheduledDate: parseFlexibleDate(job.scheduledDate),
        initialScheduledStartAt: job.scheduledStartAt,
        initialEstimatedDurationMinutes: job.estimatedDurationMinutes,
        initialActualDurationMinutes: job.actualDurationMinutes,
        initialCleanerEmployeeId: initialCleanerEmployeeId,
        initialStatus: job.status,
      ),
    );
    if (result == null) return;

    if (AppEnv.isDemoMode) {
      await _showDemoCreateDialog(
        title: 'Demo Job Updated',
        message:
            'Job "${job.jobNumber}" update flow completed in preview walkthrough mode. No database changes were made.',
      );
      return;
    }

    final profileId = _profileIdForLocation(
      result.locationId,
      fallbackProfileId: job.profileId,
    );
    if (profileId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No cleaning profile found for selected location. Create a cleaning profile first.',
          ),
        ),
      );
      return;
    }

    // Use the status from the form, or calculate it if not provided
    final selectedStatus = result.status ?? switch ((
      job.status.trim().toLowerCase(),
      result.cleanerEmployeeId,
    )) {
      ('completed', null) => 'completed',
      ('canceled', _) || ('cancelled', _) => 'canceled',
      (_, null) => 'pending',
      ('pending', _) || ('assigned', _) => 'assigned',
      _ => job.status,
    };

    try {
      final assignments = await _api.listJobAssignments(
        job.id,
        bearerToken: _token,
      );
      final activeAssignments = assignments
          .where((assignment) => assignment.isActive)
          .toList();
      if (result.cleanerEmployeeId == null) {
        for (final assignment in activeAssignments) {
          await _api.deleteJobAssignment(
            job.id,
            assignment.id,
            bearerToken: _token,
          );
        }
      } else {
        final hasSelectedAssignee = activeAssignments.any(
          (assignment) => assignment.employeeId == result.cleanerEmployeeId,
        );
        if (!hasSelectedAssignee) {
          for (final assignment in activeAssignments) {
            await _api.deleteJobAssignment(
              job.id,
              assignment.id,
              bearerToken: _token,
            );
          }
          await _api.createJobAssignment(
            job.id,
            JobAssignmentCreateInput(employeeId: result.cleanerEmployeeId!),
            bearerToken: _token,
          );
        }
      }
      await _api.updateJob(
        job.id,
        JobUpdateInput(
          profileId: profileId,
          scheduledDate: result.scheduledDate,
          scheduledStartAt: result.scheduledStartAt,
          status: selectedStatus,
          estimatedDurationMinutes: result.estimatedDurationMinutes,
          actualDurationMinutes: result.actualDurationMinutes,
          notes: job.notes,
        ),
        bearerToken: _token,
      );
      await _loadAdminData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Job updated')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  Future<void> _deleteJob(Job job) async {
    final confirmed = await showDeleteConfirmationDialog(
      context,
      itemType: 'job',
      itemName: '${job.clientName ?? 'Unknown Client'} on ${formatDateMdy(job.scheduledDate)}',
    );
    if (confirmed != true) return;

    if (AppEnv.isDemoMode) {
      await _showDemoCreateDialog(
        title: 'Demo Job Deleted',
        message:
            'Job "${job.jobNumber}" was removed in preview walkthrough mode. No database changes were made.',
      );
      return;
    }

    try {
      final message = await _api.deleteJob(job.id, bearerToken: _token);
      await _loadAdminData();
      if (!mounted) return;
      showSuccessSnackBar(context, message);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  Future<void> _showCreateCleaningProfileDialog() async {
    if (_locations.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Create a location first')));
      return;
    }

    final result = await showDialog<CleaningProfileCreateInput>(
      context: context,
      builder: (context) => CleaningProfileEditorDialog(locations: _locations),
    );
    if (result == null) return;

    if (AppEnv.isDemoMode) {
      await _showDemoCreateDialog(
        title: 'Demo Cleaning Profile Created',
        message:
            'Cleaning profile "${result.name}" was created in preview mode for walkthrough purposes. No database changes were made.',
      );
      return;
    }

    try {
      await _api.createCleaningProfile(result, bearerToken: _token);
      await _loadAdminData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cleaning profile created')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  Future<void> _showEditCleaningProfileDialog(CleaningProfile profile) async {
    if (AppEnv.isDemoMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo mode: create/edit/delete actions are disabled'),
        ),
      );
      return;
    }

    final result = await showDialog<CleaningProfileUpdateInput>(
      context: context,
      builder: (context) => CleaningProfileEditorDialog(
        locations: _locations,
        isCreate: false,
        selectedLocationId: profile.locationId,
        name: profile.name,
        notes: profile.notes ?? '',
      ),
    );
    if (result == null) return;

    try {
      await _api.updateCleaningProfile(profile.id, result, bearerToken: _token);
      await _loadAdminData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cleaning profile updated')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  Future<void> _deleteCleaningProfile(CleaningProfile profile) async {
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
        title: const Text('Delete cleaning profile'),
        content: Text('Delete ${profile.name}?'),
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
      final message = await _api.deleteCleaningProfile(
        profile.id,
        bearerToken: _token,
      );
      await _loadAdminData();
      if (!mounted) return;
      showSuccessSnackBar(context, message);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  Future<void> _loadProfileTasks(
    String profileId, {
    bool setLoading = true,
  }) async {
    if (setLoading && mounted) {
      setState(() => _loadingProfileTasks = true);
    }
    try {
      final tasks = await _api.listProfileTasks(profileId, bearerToken: _token);
      if (!mounted) return;
      setState(() {
        _selectedProfileTasks = tasks;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    } finally {
      if (setLoading && mounted) {
        setState(() => _loadingProfileTasks = false);
      }
    }
  }

  Future<void> _selectCleaningProfile(String profileId) async {
    setState(() {
      _selectedCleaningProfileId = profileId;
      _selectedProfileTasks = const [];
      _loadingProfileTasks = true;
    });
    await _loadProfileTasks(profileId, setLoading: false);
    if (mounted) {
      setState(() => _loadingProfileTasks = false);
    }
  }

  Future<void> _showAddProfileTaskDialog() async {
    if (_selectedCleaningProfileId == null) {
      showErrorSnackBar(context, 'Select a cleaning profile first');
      return;
    }
    if (_taskDefinitions.isEmpty) {
      showErrorSnackBar(context, 'Create task definitions first');
      return;
    }

    final result = await showDialog<ProfileTaskCreateInput>(
      context: context,
      builder: (context) =>
          ProfileTaskEditorDialog(taskDefinitions: _taskDefinitions),
    );
    if (result == null) return;

    if (AppEnv.isDemoMode) {
      await _showDemoCreateDialog(
        title: 'Demo Profile Task Linked',
        message:
            'Task "${_taskDefinitionLabel(result.taskDefinitionId)}" was linked to the selected profile in preview walkthrough mode. No database changes were made.',
      );
      return;
    }

    try {
      await _api.createProfileTask(
        _selectedCleaningProfileId!,
        result,
        bearerToken: _token,
      );
      await _loadProfileTasks(_selectedCleaningProfileId!);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile task linked')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  Future<void> _showEditProfileTaskDialog(ProfileTask profileTask) async {
    if (AppEnv.isDemoMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo mode: create/edit/delete actions are disabled'),
        ),
      );
      return;
    }
    if (_selectedCleaningProfileId == null) return;

    final result = await showDialog<ProfileTaskUpdateInput>(
      context: context,
      builder: (context) => ProfileTaskEditorDialog(
        taskDefinitions: _taskDefinitions,
        isCreate: false,
        selectedTaskDefinitionId: profileTask.taskDefinitionId,
        requiredValue: profileTask.required,
        displayOrderValue: profileTask.displayOrder,
        taskMetadataValue: profileTask.taskMetadata ?? const {},
      ),
    );
    if (result == null) return;

    try {
      await _api.updateProfileTask(
        _selectedCleaningProfileId!,
        profileTask.id,
        result,
        bearerToken: _token,
      );
      await _loadProfileTasks(_selectedCleaningProfileId!);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile task updated')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  Future<void> _deleteProfileTask(ProfileTask profileTask) async {
    if (AppEnv.isDemoMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo mode: create/edit/delete actions are disabled'),
        ),
      );
      return;
    }
    if (_selectedCleaningProfileId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlink profile task'),
        content: const Text('Remove this task from the selected profile?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final message = await _api.deleteProfileTask(
        _selectedCleaningProfileId!,
        profileTask.id,
        bearerToken: _token,
      );
      await _loadProfileTasks(_selectedCleaningProfileId!);
      if (!mounted) return;
      showSuccessSnackBar(context, message);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  Future<void> _showCreateTaskDefinitionDialog() async {
    final result = await showDialog<TaskDefinitionCreateInput>(
      context: context,
      builder: (context) => const TaskDefinitionEditorDialog(),
    );
    if (result == null) return;

    if (AppEnv.isDemoMode) {
      await _showDemoCreateDialog(
        title: 'Demo Task Definition Created',
        message:
            'Task definition "${result.name}" was created in preview mode for walkthrough purposes. No database changes were made.',
      );
      return;
    }

    try {
      await _api.createTaskDefinition(result, bearerToken: _token);
      await _loadAdminData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Task definition created')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  Future<void> _showCreateTaskRuleDialog() async {
    if (_taskDefinitions.isEmpty) {
      showErrorSnackBar(context, 'Create a task definition first');
      return;
    }

    final result = await showDialog<TaskRuleCreateInput>(
      context: context,
      builder: (context) =>
          TaskRuleEditorDialog(taskDefinitions: _taskDefinitions),
    );
    if (result == null) return;

    if (AppEnv.isDemoMode) {
      await _showDemoCreateDialog(
        title: 'Demo Task Rule Created',
        message:
            'Task rule for "${_taskDefinitionLabel(result.taskDefinitionId)}" was created in preview mode for walkthrough purposes. No database changes were made.',
      );
      return;
    }

    try {
      await _api.createTaskRule(result, bearerToken: _token);
      await _loadAdminData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Task rule created')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  List<Employee> get _filteredEmployees {
    var filtered = _employees.where((employee) {
      final status = employee.status.trim().toLowerCase();
      switch (_employeeFilter) {
        case _EmployeeFilter.active:
          return status == 'active';
        case _EmployeeFilter.invited:
          return status == 'invited';
        case _EmployeeFilter.all:
          return true;
      }
    }).toList();
    
    // Apply search filter
    if (_employeeSearch.isNotEmpty) {
      final searchLower = _employeeSearch.toLowerCase();
      filtered = filtered.where((employee) {
        return employee.name.toLowerCase().contains(searchLower) ||
            (employee.email?.toLowerCase().contains(searchLower) ?? false);
      }).toList();
    }
    
    filtered.sort((a, b) {
      final aDeleted = a.status.trim().toLowerCase() == 'deleted';
      final bDeleted = b.status.trim().toLowerCase() == 'deleted';
      if (aDeleted != bDeleted) {
        return aDeleted ? 1 : -1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return filtered;
  }

  List<Client> get _filteredClients {
    var filtered = _clients.where((client) {
      final status = client.status.trim().toLowerCase();
      switch (_clientFilter) {
        case _ClientFilter.active:
          return status == 'active' || status == 'invited';
        case _ClientFilter.inactive:
          return status != 'active' && status != 'invited';
        case _ClientFilter.all:
          return true;
      }
    }).toList();
    
    // Apply search filter
    if (_clientSearch.isNotEmpty) {
      final searchLower = _clientSearch.toLowerCase();
      filtered = filtered.where((client) {
        return client.name.toLowerCase().contains(searchLower) ||
            (client.email?.toLowerCase().contains(searchLower) ?? false);
      }).toList();
    }
    
    // Apply sorting if column selected
    if (_clientsSortColumnIndex != null) {
      filtered.sort((a, b) {
        int comparison = 0;
        switch (_clientsSortColumnIndex) {
          case 0: // Status - invited first, then active, deleted last
            final aStatus = a.status.trim().toLowerCase();
            final bStatus = b.status.trim().toLowerCase();
            if (aStatus == 'invited' && bStatus != 'invited') {
              comparison = -1;
            } else if (aStatus != 'invited' && bStatus == 'invited') {
              comparison = 1;
            } else if (aStatus == 'deleted' && bStatus != 'deleted') {
              comparison = 1;
            } else if (aStatus != 'deleted' && bStatus == 'deleted') {
              comparison = -1;
            } else {
              comparison = aStatus.compareTo(bStatus);
            }
            break;
          case 1: // Name
            comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
            break;
          case 2: // Email
            comparison = (a.email ?? '').toLowerCase().compareTo((b.email ?? '').toLowerCase());
            break;
          case 3: // Phone
            comparison = (a.phoneNumber ?? '').compareTo(b.phoneNumber ?? '');
            break;
        }
        return _clientsSortAscending ? comparison : -comparison;
      });
    } else {
      // Default sort: invited first, then active, then others, deleted last
      filtered.sort((a, b) {
        final aStatus = a.status.trim().toLowerCase();
        final bStatus = b.status.trim().toLowerCase();
        
        // Invited always comes first
        if (aStatus == 'invited' && bStatus != 'invited') {
          return -1;
        } else if (aStatus != 'invited' && bStatus == 'invited') {
          return 1;
        }
        
        // Deleted always comes last
        if (aStatus == 'deleted' && bStatus != 'deleted') {
          return 1;
        } else if (aStatus != 'deleted' && bStatus == 'deleted') {
          return -1;
        }
        
        // Otherwise sort by name
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    }
    
    return filtered;
  }

  List<Location> get _filteredLocations {
    var filtered = _locations.where((location) {
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
    
    // Apply search filter
    if (_locationSearch.isNotEmpty) {
      final searchLower = _locationSearch.toLowerCase();
      filtered = filtered.where((location) {
        return (location.address?.toLowerCase().contains(searchLower) ?? false) ||
            (location.city?.toLowerCase().contains(searchLower) ?? false) ||
            location.locationNumber.toLowerCase().contains(searchLower);
      }).toList();
    }
    
    filtered.sort((a, b) {
      final aDeleted = a.status.trim().toLowerCase() == 'deleted';
      final bDeleted = b.status.trim().toLowerCase() == 'deleted';
      if (aDeleted != bDeleted) {
        return aDeleted ? 1 : -1;
      }
      final aAddress = (a.address ?? '').toLowerCase();
      final bAddress = (b.address ?? '').toLowerCase();
      return aAddress.compareTo(bAddress);
    });
    return filtered;
  }

  List<Client> get _activeClients {
    return _clients
        .where((client) => client.status.trim().toLowerCase() == 'active')
        .toList();
  }

  List<Location> get _activeLocations {
    return _locations
        .where((location) => location.status.trim().toLowerCase() == 'active')
        .toList();
  }

  List<Employee> get _activeCleaners {
    return _employees
        .where((employee) => employee.status.trim().toLowerCase() == 'active')
        .toList();
  }

  int? _profileIdForLocation(int locationId, {int? fallbackProfileId}) {
    for (final profile in _cleaningProfiles) {
      if (profile.locationId == locationId) {
        return int.tryParse(profile.id);
      }
    }
    return fallbackProfileId;
  }

  bool _isOverdue(Job job) {
    final status = job.status.trim().toLowerCase();
    if (status == 'completed' ||
        status == 'canceled' ||
        status == 'cancelled') {
      return false;
    }
    final parsed = parseFlexibleDate(job.scheduledDate);
    if (parsed == null) return false;
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    return parsed.isBefore(startOfToday);
  }

  List<Job> get _filteredJobs {
    final filtered = _jobs.where((job) {
      // Status filter
      final status = job.status.trim().toLowerCase();
      final statusMatches = switch (_jobFilter) {
        _JobFilter.active => status == 'pending' || status == 'assigned' || status == 'in_progress' || status == 'in-progress',
        _JobFilter.all => true,
      };
      
      if (!statusMatches) return false;
      
      // Client search filter
      if (_jobClientSearch.isNotEmpty) {
        final clientName = (job.clientName ?? '').toLowerCase();
        final searchTerm = _jobClientSearch.toLowerCase();
        if (!clientName.contains(searchTerm)) {
          return false;
        }
      }
      
      return true;
    }).toList();

    // Apply sorting
    if (_jobsSortColumnIndex != null) {
      filtered.sort((a, b) {
        int comparison = 0;
        switch (_jobsSortColumnIndex) {
          case 0: // Status - Custom order: pending first, then alphabetical
            final statusA = a.status.trim().toLowerCase();
            final statusB = b.status.trim().toLowerCase();
            
            // Pending always comes first
            if (statusA == 'pending' && statusB != 'pending') {
              comparison = -1;
            } else if (statusA != 'pending' && statusB == 'pending') {
              comparison = 1;
            } else {
              // Both pending or both non-pending, sort alphabetically
              comparison = a.status.compareTo(b.status);
            }
            break;
          case 1: // Date
            final dateA = parseFlexibleDate(a.scheduledDate);
            final dateB = parseFlexibleDate(b.scheduledDate);
            if (dateA != null && dateB != null) {
              comparison = dateA.compareTo(dateB);
            }
            break;
          case 2: // Client
            comparison = (a.clientName ?? '').compareTo(b.clientName ?? '');
            break;
          case 3: // Location
            final locA = a.locationCity ?? a.locationAddress ?? '';
            final locB = b.locationCity ?? b.locationAddress ?? '';
            comparison = locA.compareTo(locB);
            break;
          case 4: // Cleaner
            final cleanersA = _jobAssignments[a.id]?.join(', ') ?? '';
            final cleanersB = _jobAssignments[b.id]?.join(', ') ?? '';
            comparison = cleanersA.compareTo(cleanersB);
            break;
          case 5: // Estimated Duration
            comparison = (a.estimatedDurationMinutes ?? 0).compareTo(b.estimatedDurationMinutes ?? 0);
            break;
          case 6: // Actual Duration
            comparison = (a.actualDurationMinutes ?? 0).compareTo(b.actualDurationMinutes ?? 0);
            break;
        }
        return _jobsSortAscending ? comparison : -comparison;
      });
    }

    return filtered;
  }

  String _locationLabel(int? locationId) {
    if (locationId == null) return 'N/A';
    for (final location in _locations) {
      if (int.tryParse(location.id) == locationId) {
        return location.locationNumber;
      }
    }
    return 'Location $locationId';
  }

  String _taskDefinitionLabel(int taskDefinitionId) {
    for (final definition in _taskDefinitions) {
      if (int.tryParse(definition.id) == taskDefinitionId) {
        return '${definition.code} • ${definition.name}';
      }
    }
    return 'Definition $taskDefinitionId';
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
    return _jobs.where(_isOverdue).length;
  }

  Future<void> _updateCleaningRequestStatus(
    CleaningRequest request,
    String status,
  ) async {
    try {
      await _api.updateCleaningRequestStatus(
        request.id,
        status,
        bearerToken: _token,
      );
      await _loadAdminData();
      if (!mounted) return;
      showSuccessSnackBar(context, 'Request #${request.id} moved to $status.');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
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

  TextStyle get _tableHeaderStyle =>
      const TextStyle(fontWeight: FontWeight.w800);

  DataColumn _tableColumn(String label) {
    return DataColumn(label: Text(label, style: _tableHeaderStyle));
  }

  Widget _rowActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      splashRadius: 14,
      iconSize: 18,
      onPressed: onPressed,
    );
  }

  Widget _centeredSectionBody(Widget child, {double maxWidth = 1240}) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }

  String _clientNameById(int clientId) {
    for (final client in _clients) {
      if (int.tryParse(client.id) == clientId) {
        return client.name;
      }
    }
    return 'Client $clientId';
  }

  String _adminDisplayName() {
    final email = AuthSession.current?.loginEmail?.trim() ?? '';
    if (email.isEmpty) return 'Admin';
    final local = email
        .split('@')
        .first
        .replaceAll(RegExp(r'[._-]+'), ' ')
        .trim();
    if (local.isEmpty) return 'Admin';
    return local
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  Widget _buildAdminWelcomeCard(bool dark) {
    final panelBg = dark ? const Color(0xFF333740) : const Color(0xFFE8F3FA);
    final panelBorder = dark
        ? const Color(0xFF4A525F)
        : const Color(0xFFA8D6F7);
    final panelTitle = dark ? const Color(0xFFB39CD0) : const Color(0xFF442E6F);
    return Card(
      color: panelBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: panelBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 27,
              backgroundColor: Color(0xFFA8D6F7),
              backgroundImage: AssetImage(
                'assets/images/profiles/admin_profile.png',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Welcome, ${_adminDisplayName()}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: panelTitle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openJobsOverdue() {
    setState(() {
      _selectedSection = AdminSection.management;
      _managementModel = ManagementModel.jobs;
      _jobFilter = _JobFilter.all;
    });
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
      case AdminSection.dashboard:
        return DashboardSection(
              jobs: _jobs,
              employees: _employees,
              cleaningRequests: _cleaningRequests,
              cleaningRequestFilter: _cleaningRequestFilter,
              totalPendingJobs: _totalPendingJobs,
              totalAssignedJobs: _totalAssignedJobs,
              totalInProgressJobs: _totalInProgressJobs,
              totalCompletedJobs: _totalCompletedJobs,
              totalOverdueJobs: _totalOverdueJobs,
              onCleaningRequestFilterChanged: (filter) => setState(() => _cleaningRequestFilter = filter),
              onUpdateCleaningRequestStatus: _updateCleaningRequestStatus,
              onOpenJobsOverdue: _openJobsOverdue,
              getClientNameById: _clientNameById,
              buildSectionHeader: _buildSectionHeader,
              buildMetricTile: _metricTile,
            );
      case AdminSection.cleaningProfiles:
        return CleaningProfilesSection(
              cleaningProfiles: _cleaningProfiles,
              selectedProfileTasks: _selectedProfileTasks,
              taskDefinitions: _taskDefinitions,
              taskRules: _taskRules,
              selectedProfileId: _selectedCleaningProfileId,
              loadingProfileTasks: _loadingProfileTasks,
              onCreateProfile: _showCreateCleaningProfileDialog,
              onCreateTaskDefinition: _showCreateTaskDefinitionDialog,
              onCreateTaskRule: _showCreateTaskRuleDialog,
              onAddProfileTask: _showAddProfileTaskDialog,
              onSelectProfile: _selectCleaningProfile,
              onEditProfile: _showEditCleaningProfileDialog,
              onDeleteProfile: _deleteCleaningProfile,
              onEditProfileTask: _showEditProfileTaskDialog,
              onDeleteProfileTask: _deleteProfileTask,
              getLocationLabel: _locationLabel,
              getTaskDefinitionLabel: _taskDefinitionLabel,
              buildSectionHeader: _buildSectionHeader,
              buildCenteredSection: _centeredSectionBody,
              buildTableColumn: _tableColumn,
            );
      case AdminSection.management:
        return ManagementSection(
              managementModel: _managementModel,
              filteredEmployees: _filteredEmployees,
              filteredClients: _filteredClients,
              filteredLocations: _filteredLocations,
              filteredJobs: _filteredJobs,
              jobAssignments: _jobAssignments,
              jobDateRange: _jobDateRange,
              jobFilter: _jobFilter.name,
              jobClientSearch: _jobClientSearch,
              employeeSearch: _employeeSearch,
              clientSearch: _clientSearch,
              locationSearch: _locationSearch,
              jobsSortColumnIndex: _jobsSortColumnIndex,
              jobsSortAscending: _jobsSortAscending,
              clientsSortColumnIndex: _clientsSortColumnIndex,
              clientsSortAscending: _clientsSortAscending,
              activeOnlyFilter: _activeOnlyFilter,
              onManagementModelChanged: (model) => setState(() => _managementModel = model),
              onActiveOnlyFilterChanged: (active) => setState(() => _activeOnlyFilter = active),
              onJobFilterChanged: (filter) {
                setState(() {
                  _jobFilter = _JobFilter.values.firstWhere(
                    (f) => f.name == filter,
                    orElse: () => _JobFilter.all,
                  );
                });
              },
              onJobClientSearchChanged: (search) => setState(() => _jobClientSearch = search),
              onEmployeeSearchChanged: (search) => setState(() => _employeeSearch = search),
              onClientSearchChanged: (search) => setState(() => _clientSearch = search),
              onLocationSearchChanged: (search) => setState(() => _locationSearch = search),
              onJobDateRangeChanged: (range) => setState(() => _jobDateRange = range),
              onJobsSort: (columnIndex, ascending) {
                setState(() {
                  _jobsSortColumnIndex = columnIndex;
                  _jobsSortAscending = ascending;
                });
              },
              onClientsSort: (columnIndex, ascending) {
                setState(() {
                  _clientsSortColumnIndex = columnIndex;
                  _clientsSortAscending = ascending;
                });
              },
              onShowCreateDialog: _showCreateDialog,
              onShowCreateClientDialog: _showCreateClientDialog,
              onShowCreateLocationDialog: _showCreateLocationDialog,
              onShowCreateJobDialog: _showCreateJobDialog,
              onShowEditDialog: _showEditDialog,
              onShowEditClientDialog: _showEditClientDialog,
              onShowEditLocationDialog: _showEditLocationDialog,
              onShowEditJobDialog: _showEditJobDialog,
              onDeleteEmployee: _deleteEmployee,
              onDeleteClient: _deleteClient,
              onDeleteLocation: _deleteLocation,
              onDeleteJob: _deleteJob,
              buildSectionHeader: _buildSectionHeader,
              buildCenteredSection: _centeredSectionBody,
              buildTableColumn: _tableColumn,
              buildRowActionButton: _rowActionButton,
              getLocationLabel: _locationLabel,
              isOverdue: _isOverdue,
            );
      case AdminSection.reports:
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
      case AdminSection.knowledgeBase:
        return _buildCrudScaffoldSection(
          title: 'Knowledge Base',
          subtitle:
              'Reference guides and SOP content for field + office teams.',
          actions: [
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/knowledge-base'),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open Knowledge Base'),
            ),
          ],
          bodyText:
              'Use this area for cleaning technique guides, product standards, and role-based checklists.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final isDark = baseTheme.brightness == Brightness.dark;
    const lightPrimary = Color(0xFF296273);
    const lightAccent = Color(0xFF442E6F);
    const lightCta = Color(0xFFEE7E32);
    const lightSupport = Color(0xFFA8D6F7);
    const darkSurface = Color(0xFF1F1F1F);
    const darkBg = Color(0xFF2C2C2C);
    const darkText = Color(0xFFE4E4E4);
    const darkAccent = Color(0xFFA8DADC);
    const darkCta = Color(0xFFB39CD0);
    final isCompactLayout = MediaQuery.sizeOf(context).width < 1024;

    final adminTheme = baseTheme.copyWith(
      scaffoldBackgroundColor: isDark ? darkBg : Colors.white,
      canvasColor: isDark ? darkBg : Colors.white,
      cardColor: isDark ? darkSurface : const Color(0xFFF7FCFE),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF333740) : const Color(0xFFF7FCFE),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark
                ? const Color(0xFF4A525F)
                : lightPrimary.withValues(alpha: 0.28),
          ),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(
          isDark ? const Color(0xFF2D3139) : const Color(0xFFEAF5FA),
        ),
        dataRowColor: WidgetStatePropertyAll(
          isDark ? const Color(0xFF333740) : const Color(0xFFF7FCFE),
        ),
        headingTextStyle: TextStyle(
          color: isDark ? darkText : lightAccent,
          fontWeight: FontWeight.w800,
        ),
        dataTextStyle: TextStyle(color: isDark ? darkText : lightPrimary),
      ),
      dividerColor: isDark
          ? darkAccent.withValues(alpha: 0.25)
          : lightPrimary.withValues(alpha: 0.25),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: isDark ? darkCta : lightCta,
          foregroundColor: Colors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? darkAccent : lightAccent,
          side: BorderSide(
            color: isDark
                ? darkAccent.withValues(alpha: 0.45)
                : lightPrimary.withValues(alpha: 0.45),
          ),
        ),
      ),
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: isDark
            ? const Color(0xFF2A2A2A)
            : lightSupport.withValues(alpha: 0.25),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark
                ? darkAccent.withValues(alpha: 0.35)
                : lightPrimary.withValues(alpha: 0.35),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark
                ? darkAccent.withValues(alpha: 0.35)
                : lightPrimary.withValues(alpha: 0.35),
          ),
        ),
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        backgroundColor: isDark
            ? const Color(0xFF2A2A2A)
            : lightSupport.withValues(alpha: 0.3),
        selectedColor: isDark
            ? darkCta.withValues(alpha: 0.28)
            : lightAccent.withValues(alpha: 0.2),
        side: BorderSide(
          color: isDark
              ? darkAccent.withValues(alpha: 0.45)
              : lightPrimary.withValues(alpha: 0.35),
        ),
        labelStyle: TextStyle(
          color: isDark ? darkText : lightAccent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? darkBg : Colors.white,
      drawer: isCompactLayout
          ? Drawer(
              child: SafeArea(
                child: AdminSidebar(
                  collapsed: false,
                  forDrawer: true,
                  selectedSection: _selectedSection,
                  onSectionChanged: (section) =>
                      setState(() => _selectedSection = section),
                ),
              ),
            )
          : null,
      bottomNavigationBar: const SafeArea(top: false, child: BackendBanner()),
      appBar: AppBar(
        leading: isCompactLayout
            ? IconButton(
                tooltip: 'Menu',
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              )
            : IconButton(
                tooltip: _sidebarCollapsed
                    ? 'Expand sidebar'
                    : 'Collapse sidebar',
                icon: Icon(_sidebarCollapsed ? Icons.menu_open : Icons.menu),
                onPressed: () =>
                    setState(() => _sidebarCollapsed = !_sidebarCollapsed),
              ),
        title: const BrandAppBarTitle(),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            onPressed: _loading ? null : _loadAdminData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          ProfileMenuButton(onProfileUpdated: _loadAdminData),
        ],
      ),
      body: Theme(
        data: adminTheme,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [
                      Color(0xFF2C2C2C),
                      Color(0xFF26262B),
                      Color(0xFF30303A),
                    ]
                  : const [Colors.white, Color(0xFFA8D6F7), Color(0xFFE7F3FB)],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
          child: SafeArea(
            child: SelectionArea(
              child: Row(
                children: [
                  if (!isCompactLayout)
                    AdminSidebar(collapsed: _sidebarCollapsed, selectedSection: _selectedSection, onSectionChanged: (section) => setState(() => _selectedSection = section)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildAdminWelcomeCard(isDark),
                          const SizedBox(height: 12),
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
                                  'Demo mode is enabled: create flows are interactive, but no data is persisted.',
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
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : _buildSectionContent(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CleaningProfileEditorDialogState
    extends State<CleaningProfileEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _notes;
  int? _selectedLocationId;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.name);
    _notes = TextEditingController(text: widget.notes);
    _selectedLocationId =
        widget.selectedLocationId ?? int.tryParse(widget.locations.first.id);
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildCrudModalTheme(context),
      child: AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.isCreate
                    ? 'Create Cleaning Profile'
                    : 'Edit Cleaning Profile',
                style: TextStyle(
                  color: crudModalTitleColor(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset(
                'assets/images/logo.png',
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _selectedLocationId,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.locations
                      .map(
                        (location) => DropdownMenuItem<int>(
                          value: int.tryParse(location.id),
                          child: Text(location.locationNumber),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedLocationId = value),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Profile Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
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
              if (_selectedLocationId == null || _name.text.trim().isEmpty) {
                return;
              }
              if (widget.isCreate) {
                Navigator.pop(
                  context,
                  CleaningProfileCreateInput(
                    locationId: _selectedLocationId!,
                    name: _name.text.trim(),
                    notes: _notes.text.trim().isEmpty
                        ? null
                        : _notes.text.trim(),
                  ),
                );
              } else {
                Navigator.pop(
                  context,
                  CleaningProfileUpdateInput(
                    locationId: _selectedLocationId!,
                    name: _name.text.trim(),
                    notes: _notes.text.trim().isEmpty
                        ? null
                        : _notes.text.trim(),
                  ),
                );
              }
            },
            child: Text(widget.isCreate ? 'Create' : 'Save'),
          ),
        ],
      ),
    );
  }
}

class TaskDefinitionEditorDialogState
    extends State<TaskDefinitionEditorDialog> {
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController();
    _name = TextEditingController();
    _category = TextEditingController(text: 'general');
    _description = TextEditingController();
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _category.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Task Definition'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_code, 'Code (e.g. KITCHEN_DUST)'),
              const SizedBox(height: 10),
              _field(_name, 'Name'),
              const SizedBox(height: 10),
              _field(_category, 'Category'),
              const SizedBox(height: 10),
              _field(_description, 'Description (optional)', maxLines: 2),
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
            if (_code.text.trim().isEmpty ||
                _name.text.trim().isEmpty ||
                _category.text.trim().isEmpty) {
              return;
            }
            Navigator.pop(
              context,
              TaskDefinitionCreateInput(
                code: _code.text.trim(),
                name: _name.text.trim(),
                category: _category.text.trim(),
                description: _description.text.trim().isEmpty
                    ? null
                    : _description.text.trim(),
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

