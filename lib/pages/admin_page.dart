import 'dart:convert';

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
import '../utils/date_format.dart';
import '../utils/error_text.dart';
import '../widgets/backend_banner.dart';
import '../widgets/brand_app_bar_title.dart';
import '../widgets/demo_mode_notice.dart';
import '../widgets/duration_picker_fields.dart';
import '../widgets/profile_menu_button.dart';
import '../widgets/theme_toggle_button.dart';

enum _AdminSection {
  dashboard,
  jobs,
  cleaningProfiles,
  management,
  reports,
  knowledgeBase,
}

enum _ManagementModel { employees, clients, locations }

enum _EmployeeFilter { all, active, invited }

enum _ClientFilter { all, active, inactive }

enum _LocationFilter { all, active, inactive }

enum _JobFilter { all, pending, assigned, inProgress, completed, overdue }

enum _CleaningRequestFilter { open, reviewed, scheduled, closed, all }

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  static const String _defaultEmployeePhotoAsset =
      '/assets/images/profiles/employee_default.png';
  static const String _defaultLocationPhotoAsset =
      '/assets/images/locations/location_default.png';
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
  Map<String, String> _jobCleanerNameByJobId = const {};
  List<Client> _clients = const [];
  List<Location> _locations = const [];
  List<CleaningProfile> _cleaningProfiles = const [];
  List<CleaningRequest> _cleaningRequests = const [];
  List<TaskDefinition> _taskDefinitions = const [];
  List<TaskRule> _taskRules = const [];
  List<ProfileTask> _selectedProfileTasks = const [];
  _AdminSection _selectedSection = _AdminSection.dashboard;
  _ManagementModel _managementModel = _ManagementModel.employees;
  _EmployeeFilter _employeeFilter = _EmployeeFilter.active;
  _ClientFilter _clientFilter = _ClientFilter.active;
  _LocationFilter _locationFilter = _LocationFilter.active;
  _JobFilter _jobFilter = _JobFilter.all;
  DateTimeRange _jobDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now().add(const Duration(days: 30)),
  );
  _CleaningRequestFilter _cleaningRequestFilter = _CleaningRequestFilter.open;
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
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showPolishedDeleteDialog({
    required String title,
    required String message,
  }) async {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final dialogTheme = Theme.of(context).copyWith(
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? const Color(0xFF333740) : null,
        surfaceTintColor: Colors.transparent,
      ),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Theme(
        data: dialogTheme,
        child: AlertDialog(
          title: Text(
            title,
            style: TextStyle(
              color: dark ? const Color(0xFFB39CD0) : const Color(0xFF442E6F),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(color: dark ? const Color(0xFFE4E4E4) : null),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: dark
                    ? const Color(0xFFB39CD0)
                    : const Color(0xFF442E6F),
                foregroundColor: dark ? const Color(0xFF1F1F1F) : Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
    return confirmed == true;
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
    Navigator.pushReplacementNamed(context, '/admin');
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
      final cleanerNameById = <String, String>{};
      for (final employee in employees) {
        cleanerNameById[employee.id] = employee.name;
      }
      final cleanerByJobId = <String, String>{};
      for (final job in jobs) {
        try {
          final assignments = await _api.listJobAssignments(
            job.id,
            bearerToken: token,
          );
          JobAssignment? activeAssignment;
          for (final assignment in assignments) {
            if (assignment.isActive) {
              activeAssignment = assignment;
              break;
            }
          }
          if (activeAssignment != null) {
            final cleanerName =
                activeAssignment.employeeName ??
                cleanerNameById[activeAssignment.employeeId] ??
                'Unassigned';
            cleanerByJobId[job.id] = cleanerName;
          } else {
            cleanerByJobId[job.id] = 'Unassigned';
          }
        } catch (_) {
          cleanerByJobId[job.id] = 'Unassigned';
        }
      }
      final previousSelected = _selectedCleaningProfileId;
      final nextSelected = profiles.any((p) => p.id == previousSelected)
          ? previousSelected
          : (profiles.isNotEmpty ? profiles.first.id : null);

      if (!mounted) return;
      setState(() {
        _employees = employees;
        _jobs = jobs;
        _jobCleanerNameByJobId = cleanerByJobId;
        _clients = clients;
        _locations = locations;
        _cleaningProfiles = profiles;
        _cleaningRequests = cleaningRequests;
        _taskDefinitions = taskDefinitions;
        _taskRules = taskRules;
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
      builder: (context) => const _EmployeeEditorDialog(),
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
      builder: (context) => _EmployeeEditorDialog(
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

  Future<void> _delete(Employee employee) async {
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

    if (AppEnv.isDemoMode) {
      await _showDemoCreateDialog(
        title: 'Demo Employee Deleted',
        message:
            'Employee "${employee.name}" was removed in preview walkthrough mode. No database changes were made.',
      );
      return;
    }

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
    final result = await showDialog<ClientCreateInput>(
      context: context,
      builder: (context) => const _ClientEditorDialog(),
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
      builder: (context) => _ClientEditorDialog(
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

  Future<void> _deleteClient(Client client) async {
    final confirmed = await _showPolishedDeleteDialog(
      title: 'Delete client',
      message: 'Delete ${client.clientNumber} - ${client.name}?',
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
    final result = await showDialog<LocationCreateInput>(
      context: context,
      builder: (context) => _LocationEditorDialog(clients: _clients),
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
      builder: (context) => _LocationEditorDialog(
        clients: _clients,
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
    final confirmed = await _showPolishedDeleteDialog(
      title: 'Delete location',
      message:
          'Delete ${location.locationNumber} (client ${location.clientId})?',
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

  Future<void> _showCreateJobDialog() async {
    final result = await showDialog<_JobEditorFormData>(
      context: context,
      builder: (context) => _JobEditorDialog(
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
    final result = await showDialog<_JobEditorFormData>(
      context: context,
      builder: (context) => _JobEditorDialog(
        isCreate: false,
        clients: _activeClients,
        locations: activeLocations,
        cleaners: _activeCleaners,
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

    final currentStatus = job.status.trim().toLowerCase();
    final normalizedStatus = switch ((
      currentStatus,
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
          status: normalizedStatus,
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final dialogTheme = Theme.of(context).copyWith(
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? const Color(0xFF333740) : null,
        surfaceTintColor: Colors.transparent,
      ),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Theme(
        data: dialogTheme,
        child: AlertDialog(
          title: Text(
            'Delete job',
            style: TextStyle(
              color: dark ? const Color(0xFFB39CD0) : const Color(0xFF442E6F),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Delete Job for ${job.clientName ?? 'Unknown Client'} on ${formatDateMdy(job.scheduledDate)}',
            style: TextStyle(color: dark ? const Color(0xFFE4E4E4) : null),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: dark
                    ? const Color(0xFFB39CD0)
                    : const Color(0xFF442E6F),
                foregroundColor: dark ? const Color(0xFF1F1F1F) : Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
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

  Future<void> _showCreateCleaningProfileDialog() async {
    if (_locations.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Create a location first')));
      return;
    }

    final result = await showDialog<CleaningProfileCreateInput>(
      context: context,
      builder: (context) => _CleaningProfileEditorDialog(locations: _locations),
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
      builder: (context) => _CleaningProfileEditorDialog(
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a cleaning profile first')),
      );
      return;
    }
    if (_taskDefinitions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create task definitions first')),
      );
      return;
    }

    final result = await showDialog<ProfileTaskCreateInput>(
      context: context,
      builder: (context) =>
          _ProfileTaskEditorDialog(taskDefinitions: _taskDefinitions),
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
      builder: (context) => _ProfileTaskEditorDialog(
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

  Future<void> _showCreateTaskDefinitionDialog() async {
    final result = await showDialog<TaskDefinitionCreateInput>(
      context: context,
      builder: (context) => const _TaskDefinitionEditorDialog(),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a task definition first')),
      );
      return;
    }

    final result = await showDialog<TaskRuleCreateInput>(
      context: context,
      builder: (context) =>
          _TaskRuleEditorDialog(taskDefinitions: _taskDefinitions),
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
    final filtered = _employees.where((employee) {
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
    final filtered = _clients.where((client) {
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

  List<Location> get _filteredLocations {
    final filtered = _locations.where((location) {
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
    return _jobs.where((job) {
      final status = job.status.trim().toLowerCase();
      switch (_jobFilter) {
        case _JobFilter.pending:
          return status == 'pending';
        case _JobFilter.assigned:
          return status == 'assigned';
        case _JobFilter.inProgress:
          return status == 'in_progress';
        case _JobFilter.completed:
          return status == 'completed';
        case _JobFilter.overdue:
          return _isOverdue(job);
        case _JobFilter.all:
          return true;
      }
    }).toList();
  }

  String _jobFilterLabel(_JobFilter filter) {
    return switch (filter) {
      _JobFilter.pending => 'Pending',
      _JobFilter.assigned => 'Assigned',
      _JobFilter.inProgress => 'In Progress',
      _JobFilter.completed => 'Completed',
      _JobFilter.overdue => 'Overdue',
      _JobFilter.all => 'All',
    };
  }

  Future<void> _pickJobStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _jobDateRange.start,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      final currentEnd = _jobDateRange.end;
      _jobDateRange = DateTimeRange(
        start: picked,
        end: picked.isAfter(currentEnd) ? picked : currentEnd,
      );
    });
  }

  Future<void> _pickJobEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _jobDateRange.end,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      final currentStart = _jobDateRange.start;
      _jobDateRange = DateTimeRange(
        start: picked.isBefore(currentStart) ? picked : currentStart,
        end: picked,
      );
    });
  }

  String _locationLabel(int locationId) {
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

  List<CleaningRequest> get _filteredCleaningRequests {
    return _cleaningRequests.where((request) {
      final status = request.status.trim().toUpperCase();
      switch (_cleaningRequestFilter) {
        case _CleaningRequestFilter.open:
          return status == 'OPEN';
        case _CleaningRequestFilter.reviewed:
          return status == 'REVIEWED';
        case _CleaningRequestFilter.scheduled:
          return status == 'SCHEDULED';
        case _CleaningRequestFilter.closed:
          return status == 'CLOSED';
        case _CleaningRequestFilter.all:
          return true;
      }
    }).toList();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request #${request.id} moved to $status.')),
      );
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

  ({String label, Color bg, Color fg, Color border}) _employeeStatusBadge(
    Employee employee,
  ) {
    final status = employee.status.trim().toLowerCase();
    return _statusBadgeForValue(status);
  }

  ({String label, Color bg, Color fg, Color border}) _statusBadgeForValue(
    String status,
  ) {
    switch (status) {
      case 'active':
        return (
          label: 'A',
          bg: const Color(0xFFE7F4ED),
          fg: const Color(0xFF1F6A43),
          border: const Color(0xFF49A07D),
        );
      case 'invited':
        return (
          label: 'V',
          bg: const Color(0xFFFFF4E7),
          fg: const Color(0xFF9B4B12),
          border: const Color(0xFFEE7E32),
        );
      case 'deleted':
        return (
          label: 'D',
          bg: const Color(0xFFFBE7EE),
          fg: const Color(0xFFE63721),
          border: const Color(0xFFE63721),
        );
      default:
        return (
          label: status.isEmpty ? '?' : status[0].toUpperCase(),
          bg: const Color(0xFFEAF0F5),
          fg: const Color(0xFF41588E),
          border: const Color(0xFF8AA4C7),
        );
    }
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

  String _assetPath(String? value, {required String fallback}) {
    final candidate = (value == null || value.trim().isEmpty)
        ? fallback
        : value.trim();
    return candidate.startsWith('/') ? candidate.substring(1) : candidate;
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
      _selectedSection = _AdminSection.jobs;
      _jobFilter = _JobFilter.overdue;
    });
  }

  Widget _buildSidebar({required bool collapsed, bool forDrawer = false}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final sidebarBg = dark ? const Color(0xFF1F1F1F) : const Color(0xFFF7FCFE);
    final sidebarBorder = dark
        ? const Color(0xFF4A525F)
        : const Color(0xFF296273).withValues(alpha: 0.22);
    final navSelected = dark
        ? const Color(0xFFB39CD0).withValues(alpha: 0.24)
        : const Color(0xFFA8D6F7).withValues(alpha: 0.45);
    final navFg = dark ? const Color(0xFFE4E4E4) : const Color(0xFF442E6F);
    final navSelectedFg = dark
        ? const Color(0xFFB39CD0)
        : const Color(0xFF296273);

    Widget navTile({
      required _AdminSection section,
      required IconData icon,
      required String title,
    }) {
      final selected = _selectedSection == section;
      final tile = ListTile(
        dense: true,
        leading: Icon(icon, size: 24),
        iconColor: selected ? navSelectedFg : navFg,
        textColor: selected ? navSelectedFg : navFg,
        selectedTileColor: navSelected,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: EdgeInsets.symmetric(horizontal: collapsed ? 12 : 14),
        title: collapsed ? null : Text(title),
        selected: selected,
        onTap: () {
          setState(() => _selectedSection = section);
          if (forDrawer) Navigator.pop(context);
        },
      );
      if (collapsed && !forDrawer) {
        return Tooltip(message: title, child: tile);
      }
      return tile;
    }

    return Container(
      width: collapsed && !forDrawer ? 78 : 260,
      decoration: BoxDecoration(
        color: sidebarBg,
        border: Border(right: BorderSide(color: sidebarBorder)),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 8 : 16,
              vertical: 8,
            ),
            child: Row(
              children: [
                if (!collapsed || forDrawer)
                  Expanded(
                    child: Text(
                      'Admin Workspace',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: navFg,
                      ),
                    ),
                  ),
                if (!forDrawer)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    tooltip: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
                    onPressed: () =>
                        setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                    icon: Icon(
                      collapsed ? Icons.chevron_right : Icons.chevron_left,
                      color: navFg,
                    ),
                  ),
              ],
            ),
          ),
          if (collapsed && !forDrawer)
            const SizedBox(height: 2)
          else
            const SizedBox(height: 2),
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
            section: _AdminSection.management,
            icon: Icons.groups_outlined,
            title: 'People & Places',
          ),
          navTile(
            section: _AdminSection.reports,
            icon: Icons.assessment_outlined,
            title: 'Reports',
          ),
          navTile(
            section: _AdminSection.knowledgeBase,
            icon: Icons.menu_book_outlined,
            title: 'Knowledge Base',
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
    final overdueJobs = _jobs.where(_isOverdue).toList()
      ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    final utilizationAssigned = activeEmployees == 0
        ? 0.0
        : (_totalAssignedJobs / activeEmployees).clamp(0, 8) / 8;
    final utilizationCompleted = activeEmployees == 0
        ? 0.0
        : (_totalCompletedJobs / activeEmployees).clamp(0, 8) / 8;

    return ListView(
      children: [
        _buildSectionHeader(
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
                  bg: const Color.fromRGBO(231, 239, 252, 1),
                  fg: const Color.fromRGBO(31, 63, 122, 1),
                ),
                _metricTile(
                  label: 'Completed',
                  value: _totalCompletedJobs.toString(),
                  icon: Icons.task_alt,
                  bg: const Color.fromRGBO(241, 236, 252, 1),
                  fg: const Color.fromRGBO(68, 46, 111, 1),
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
                Text('Assigned capacity'),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: utilizationAssigned),
                const SizedBox(height: 10),
                Text('Completed throughput'),
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
                      selected:
                          _cleaningRequestFilter == _CleaningRequestFilter.open,
                      onSelected: (_) => setState(
                        () => _cleaningRequestFilter =
                            _CleaningRequestFilter.open,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('Reviewed'),
                      selected:
                          _cleaningRequestFilter ==
                          _CleaningRequestFilter.reviewed,
                      onSelected: (_) => setState(
                        () => _cleaningRequestFilter =
                            _CleaningRequestFilter.reviewed,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('Scheduled'),
                      selected:
                          _cleaningRequestFilter ==
                          _CleaningRequestFilter.scheduled,
                      onSelected: (_) => setState(
                        () => _cleaningRequestFilter =
                            _CleaningRequestFilter.scheduled,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('Closed'),
                      selected:
                          _cleaningRequestFilter ==
                          _CleaningRequestFilter.closed,
                      onSelected: (_) => setState(
                        () => _cleaningRequestFilter =
                            _CleaningRequestFilter.closed,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('All'),
                      selected:
                          _cleaningRequestFilter == _CleaningRequestFilter.all,
                      onSelected: (_) => setState(
                        () =>
                            _cleaningRequestFilter = _CleaningRequestFilter.all,
                      ),
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
                                '${_clientNameById(request.clientId)} • ${request.requesterName}',
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
                                        : () => _updateCleaningRequestStatus(
                                            request,
                                            'REVIEWED',
                                          ),
                                    child: const Text('Mark Reviewed'),
                                  ),
                                  OutlinedButton(
                                    onPressed: request.status == 'SCHEDULED'
                                        ? null
                                        : () => _updateCleaningRequestStatus(
                                            request,
                                            'SCHEDULED',
                                          ),
                                    child: const Text('Mark Scheduled'),
                                  ),
                                  OutlinedButton(
                                    onPressed: request.status == 'CLOSED'
                                        ? null
                                        : () => _updateCleaningRequestStatus(
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
                    onPressed: _openJobsOverdue,
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

  Widget _buildJobsSection() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final rangeStart = DateTime(
      _jobDateRange.start.year,
      _jobDateRange.start.month,
      _jobDateRange.start.day,
    );
    final rangeEnd = DateTime(
      _jobDateRange.end.year,
      _jobDateRange.end.month,
      _jobDateRange.end.day,
      23,
      59,
      59,
    );
    final rows = _filteredJobs.where((job) {
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

    String minutesLabel(int? value) {
      if (value == null || value < 0) return '—';
      final hours = value ~/ 60;
      final minutes = value % 60;
      if (hours == 0) return '${minutes}m';
      return '${hours}h ${minutes}m';
    }

    ({String label, Color bg, Color fg, Color border}) statusBadge(Job job) {
      final status = job.status.trim().toLowerCase();
      if (_isOverdue(job)) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Jobs',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _showCreateJobDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Job'),
            ),
          ],
        ),
        Expanded(
          child: _centeredSectionBody(
            Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 210,
                      child: DropdownButtonFormField<_JobFilter>(
                        initialValue: _jobFilter,
                        decoration: const InputDecoration(
                          labelText: 'Status Filter',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: _JobFilter.values
                            .map(
                              (filter) => DropdownMenuItem(
                                value: filter,
                                child: Text(_jobFilterLabel(filter)),
                              ),
                            )
                            .toList(),
                        onChanged: (next) {
                          if (next == null) return;
                          setState(() => _jobFilter = next);
                        },
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Date range',
                      style: TextStyle(
                        color: Theme.of(context).hintColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _pickJobStartDate,
                      icon: const Icon(Icons.date_range, size: 16),
                      label: Text(
                        '${_jobDateRange.start.month}-${_jobDateRange.start.day}-${_jobDateRange.start.year}',
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('to'),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      onPressed: _pickJobEndDate,
                      icon: const Icon(Icons.date_range, size: 16),
                      label: Text(
                        '${_jobDateRange.end.month}-${_jobDateRange.end.day}-${_jobDateRange.end.year}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => Card(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth,
                          ),
                          child: SingleChildScrollView(
                            child: DataTable(
                              columns: [
                                _tableColumn(''),
                                _tableColumn('Scheduled'),
                                _tableColumn('Client'),
                                _tableColumn('Cleaner'),
                                _tableColumn('Est. Duration'),
                                _tableColumn('Actual Duration'),
                                _tableColumn('Actions'),
                              ],
                              rows: rows
                                  .map(
                                    (job) => DataRow(
                                      cells: [
                                        DataCell(
                                          Builder(
                                            builder: (context) {
                                              final badge = statusBadge(job);
                                              return Container(
                                                width: 28,
                                                height: 28,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: badge.bg,
                                                  border: Border.all(
                                                    color: badge.border,
                                                    width: 1.1,
                                                  ),
                                                ),
                                                child: Text(
                                                  badge.label,
                                                  style: TextStyle(
                                                    color: badge.fg,
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            formatDateMdy(job.scheduledDate),
                                          ),
                                        ),
                                        DataCell(Text(job.clientName ?? '—')),
                                        DataCell(
                                          Text(
                                            _jobCleanerNameByJobId[job.id] ??
                                                'Unassigned',
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            minutesLabel(
                                              job.estimatedDurationMinutes,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            minutesLabel(
                                              job.actualDurationMinutes,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _rowActionButton(
                                                icon: Icons.edit,
                                                tooltip: 'Edit',
                                                onPressed: () =>
                                                    _showEditJobDialog(job),
                                              ),
                                              const SizedBox(width: 10),
                                              _rowActionButton(
                                                icon: Icons.delete,
                                                tooltip: 'Delete',
                                                onPressed: () =>
                                                    _deleteJob(job),
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
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String get _managementModelSubtitle {
    switch (_managementModel) {
      case _ManagementModel.employees:
        return '';
      case _ManagementModel.clients:
        return 'Client records and status filters.';
      case _ManagementModel.locations:
        return 'Location records and status filters.';
    }
  }

  Widget _buildManagementSection() {
    final rowsCount = switch (_managementModel) {
      _ManagementModel.employees => _filteredEmployees.length,
      _ManagementModel.clients => _filteredClients.length,
      _ManagementModel.locations => _filteredLocations.length,
    };

    final createButton = switch (_managementModel) {
      _ManagementModel.employees => (
        label: 'Create Employee',
        icon: Icons.person_add,
        onPressed: _showCreateDialog,
      ),
      _ManagementModel.clients => (
        label: 'Create Client',
        icon: Icons.business,
        onPressed: _showCreateClientDialog,
      ),
      _ManagementModel.locations => (
        label: 'Create Location',
        icon: Icons.add_location_alt,
        onPressed: _showCreateLocationDialog,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'People & Places',
          'Manage employees, clients, and locations.',
        ),
        Expanded(
          child: _centeredSectionBody(
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
                            child: DropdownButtonFormField<_ManagementModel>(
                              initialValue: _managementModel,
                              decoration: const InputDecoration(
                                labelText: 'Management Type',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: _ManagementModel.employees,
                                  child: Text('Employees'),
                                ),
                                DropdownMenuItem(
                                  value: _ManagementModel.clients,
                                  child: Text('Clients'),
                                ),
                                DropdownMenuItem(
                                  value: _ManagementModel.locations,
                                  child: Text('Locations'),
                                ),
                              ],
                              onChanged: (next) {
                                if (next == null) return;
                                setState(() => _managementModel = next);
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
                                  selected: switch (_managementModel) {
                                    _ManagementModel.employees =>
                                      _employeeFilter == _EmployeeFilter.active,
                                    _ManagementModel.clients =>
                                      _clientFilter == _ClientFilter.active,
                                    _ManagementModel.locations =>
                                      _locationFilter == _LocationFilter.active,
                                  },
                                  onSelected: (_) => setState(() {
                                    switch (_managementModel) {
                                      case _ManagementModel.employees:
                                        _employeeFilter =
                                            _EmployeeFilter.active;
                                      case _ManagementModel.clients:
                                        _clientFilter = _ClientFilter.active;
                                      case _ManagementModel.locations:
                                        _locationFilter =
                                            _LocationFilter.active;
                                    }
                                  }),
                                ),
                                ChoiceChip(
                                  label: Text(
                                    _managementModel ==
                                            _ManagementModel.employees
                                        ? 'Invited'
                                        : 'Inactive',
                                  ),
                                  selected: switch (_managementModel) {
                                    _ManagementModel.employees =>
                                      _employeeFilter ==
                                          _EmployeeFilter.invited,
                                    _ManagementModel.clients =>
                                      _clientFilter == _ClientFilter.inactive,
                                    _ManagementModel.locations =>
                                      _locationFilter ==
                                          _LocationFilter.inactive,
                                  },
                                  onSelected: (_) => setState(() {
                                    switch (_managementModel) {
                                      case _ManagementModel.employees:
                                        _employeeFilter =
                                            _EmployeeFilter.invited;
                                      case _ManagementModel.clients:
                                        _clientFilter = _ClientFilter.inactive;
                                      case _ManagementModel.locations:
                                        _locationFilter =
                                            _LocationFilter.inactive;
                                    }
                                  }),
                                ),
                                ChoiceChip(
                                  label: const Text('All'),
                                  selected: switch (_managementModel) {
                                    _ManagementModel.employees =>
                                      _employeeFilter == _EmployeeFilter.all,
                                    _ManagementModel.clients =>
                                      _clientFilter == _ClientFilter.all,
                                    _ManagementModel.locations =>
                                      _locationFilter == _LocationFilter.all,
                                  },
                                  onSelected: (_) => setState(() {
                                    switch (_managementModel) {
                                      case _ManagementModel.employees:
                                        _employeeFilter = _EmployeeFilter.all;
                                      case _ManagementModel.clients:
                                        _clientFilter = _ClientFilter.all;
                                      case _ManagementModel.locations:
                                        _locationFilter = _LocationFilter.all;
                                    }
                                  }),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '$rowsCount records',
                            style: TextStyle(
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              columns: switch (_managementModel) {
                                _ManagementModel.employees => [
                                  _tableColumn(''),
                                  _tableColumn('Name'),
                                  _tableColumn('Email'),
                                  _tableColumn('Phone'),
                                  _tableColumn('Employee #'),
                                  _tableColumn('Actions'),
                                ],
                                _ManagementModel.clients => [
                                  _tableColumn(''),
                                  _tableColumn('Name'),
                                  _tableColumn('Email'),
                                  _tableColumn('Phone'),
                                  _tableColumn('Preferred Contact Window'),
                                  _tableColumn('Actions'),
                                ],
                                _ManagementModel.locations => [
                                  _tableColumn(''),
                                  _tableColumn('Photo'),
                                  _tableColumn('Client'),
                                  _tableColumn('Type'),
                                  _tableColumn('Address'),
                                  _tableColumn('Actions'),
                                ],
                              },
                              rows: switch (_managementModel) {
                                _ManagementModel.employees =>
                                  _filteredEmployees
                                      .map(
                                        (employee) => DataRow(
                                          cells: [
                                            DataCell(
                                              Builder(
                                                builder: (context) {
                                                  final badge =
                                                      _employeeStatusBadge(
                                                        employee,
                                                      );
                                                  return Container(
                                                    width: 28,
                                                    height: 28,
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: badge.bg,
                                                      border: Border.all(
                                                        color: badge.border,
                                                        width: 1.1,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      badge.label,
                                                      style: TextStyle(
                                                        color: badge.fg,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            DataCell(Text(employee.name)),
                                            DataCell(
                                              Text(employee.email ?? '—'),
                                            ),
                                            DataCell(
                                              Text(employee.phoneNumber ?? '—'),
                                            ),
                                            DataCell(
                                              Text(employee.employeeNumber),
                                            ),
                                            DataCell(
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _rowActionButton(
                                                    icon: Icons.edit,
                                                    tooltip: 'Edit',
                                                    onPressed: () =>
                                                        _showEditDialog(
                                                          employee,
                                                        ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  _rowActionButton(
                                                    icon: Icons.delete,
                                                    tooltip: 'Delete',
                                                    onPressed:
                                                        employee.status
                                                                .trim()
                                                                .toLowerCase() ==
                                                            'deleted'
                                                        ? null
                                                        : () =>
                                                              _delete(employee),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      .toList(),
                                _ManagementModel.clients =>
                                  _filteredClients
                                      .map(
                                        (client) => DataRow(
                                          cells: [
                                            DataCell(
                                              Builder(
                                                builder: (context) {
                                                  final badge =
                                                      _statusBadgeForValue(
                                                        client.status
                                                            .trim()
                                                            .toLowerCase(),
                                                      );
                                                  return Container(
                                                    width: 28,
                                                    height: 28,
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: badge.bg,
                                                      border: Border.all(
                                                        color: badge.border,
                                                        width: 1.1,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      badge.label,
                                                      style: TextStyle(
                                                        color: badge.fg,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            DataCell(Text(client.name)),
                                            DataCell(Text(client.email ?? '—')),
                                            DataCell(
                                              Text(client.phoneNumber ?? '—'),
                                            ),
                                            DataCell(
                                              SizedBox(
                                                width: 220,
                                                child: SingleChildScrollView(
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  child: Text(
                                                    client.preferredContactWindow ??
                                                        '—',
                                                    softWrap: false,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _rowActionButton(
                                                    icon: Icons.edit,
                                                    tooltip: 'Edit',
                                                    onPressed: () =>
                                                        _showEditClientDialog(
                                                          client,
                                                        ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  _rowActionButton(
                                                    icon: Icons.delete,
                                                    tooltip: 'Delete',
                                                    onPressed:
                                                        client.status
                                                                .trim()
                                                                .toLowerCase() ==
                                                            'deleted'
                                                        ? null
                                                        : () => _deleteClient(
                                                            client,
                                                          ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      .toList(),
                                _ManagementModel.locations =>
                                  _filteredLocations
                                      .map(
                                        (location) => DataRow(
                                          cells: [
                                            DataCell(
                                              Builder(
                                                builder: (context) {
                                                  final badge =
                                                      _statusBadgeForValue(
                                                        location.status
                                                            .trim()
                                                            .toLowerCase(),
                                                      );
                                                  return Container(
                                                    width: 28,
                                                    height: 28,
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: badge.bg,
                                                      border: Border.all(
                                                        color: badge.border,
                                                        width: 1.1,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      badge.label,
                                                      style: TextStyle(
                                                        color: badge.fg,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            DataCell(
                                              CircleAvatar(
                                                radius: 14,
                                                backgroundColor: const Color(
                                                  0xFFA8D6F7,
                                                ),
                                                backgroundImage: AssetImage(
                                                  _assetPath(
                                                    location.photoUrl,
                                                    fallback:
                                                        _defaultLocationPhotoAsset,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                _clientNameById(
                                                  location.clientId,
                                                ),
                                              ),
                                            ),
                                            DataCell(Text(location.type)),
                                            DataCell(
                                              Text(
                                                [
                                                      location.address ?? '',
                                                      location.city ?? '',
                                                      location.state ?? '',
                                                      location.zipCode ?? '',
                                                    ]
                                                    .where(
                                                      (e) =>
                                                          e.trim().isNotEmpty,
                                                    )
                                                    .join(', '),
                                              ),
                                            ),
                                            DataCell(
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _rowActionButton(
                                                    icon: Icons.edit,
                                                    tooltip: 'Edit',
                                                    onPressed: () =>
                                                        _showEditLocationDialog(
                                                          location,
                                                        ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  _rowActionButton(
                                                    icon: Icons.delete,
                                                    tooltip: 'Delete',
                                                    onPressed:
                                                        location.status
                                                                .trim()
                                                                .toLowerCase() ==
                                                            'deleted'
                                                        ? null
                                                        : () => _deleteLocation(
                                                            location,
                                                          ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      .toList(),
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            maxWidth: 1220,
          ),
        ),
      ],
    );
  }

  Widget _buildCleaningProfilesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Cleaning Profiles',
          'Define reusable cleaning profiles and seed task definitions/rules.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _showCreateCleaningProfileDialog,
              icon: const Icon(Icons.add_task),
              label: const Text('Create Profile'),
            ),
            OutlinedButton.icon(
              onPressed: _showCreateTaskDefinitionDialog,
              icon: const Icon(Icons.playlist_add),
              label: const Text('Create Task Definition'),
            ),
            OutlinedButton.icon(
              onPressed: _showCreateTaskRuleDialog,
              icon: const Icon(Icons.rule),
              label: const Text('Create Task Rule'),
            ),
            FilledButton.icon(
              onPressed: _showAddProfileTaskDialog,
              icon: const Icon(Icons.link),
              label: const Text('Link Task To Selected Profile'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _centeredSectionBody(
            Column(
              children: [
                Expanded(
                  flex: 4,
                  child: Card(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columns: [
                            _tableColumn('Profile'),
                            _tableColumn('Location'),
                            _tableColumn('Notes'),
                            _tableColumn('Select'),
                            _tableColumn('Actions'),
                          ],
                          rows: _cleaningProfiles
                              .map(
                                (profile) => DataRow(
                                  selected:
                                      profile.id == _selectedCleaningProfileId,
                                  cells: [
                                    DataCell(Text(profile.name)),
                                    DataCell(
                                      Text(_locationLabel(profile.locationId)),
                                    ),
                                    DataCell(Text(profile.notes ?? '—')),
                                    DataCell(
                                      OutlinedButton(
                                        onPressed:
                                            profile.id ==
                                                _selectedCleaningProfileId
                                            ? null
                                            : () => _selectCleaningProfile(
                                                profile.id,
                                              ),
                                        child: Text(
                                          profile.id ==
                                                  _selectedCleaningProfileId
                                              ? 'Selected'
                                              : 'Select',
                                        ),
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
                                                      _showEditCleaningProfileDialog(
                                                        profile,
                                                      ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete),
                                            tooltip: 'Delete',
                                            onPressed: AppEnv.isDemoMode
                                                ? null
                                                : () => _deleteCleaningProfile(
                                                    profile,
                                                  ),
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
                const SizedBox(height: 12),
                Expanded(
                  flex: 3,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedCleaningProfileId == null
                                      ? 'Profile Tasks'
                                      : 'Profile Tasks (${_selectedProfileTasks.length})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: _selectedCleaningProfileId == null
                                      ? Center(
                                          child: Text(
                                            'Select a profile to manage linked tasks',
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).hintColor,
                                            ),
                                          ),
                                        )
                                      : _loadingProfileTasks
                                      ? const Center(
                                          child: CircularProgressIndicator(),
                                        )
                                      : ListView.builder(
                                          itemCount:
                                              _selectedProfileTasks.length,
                                          itemBuilder: (context, index) {
                                            final item =
                                                _selectedProfileTasks[index];
                                            final metadata =
                                                item.taskMetadata ?? const {};
                                            return ListTile(
                                              dense: true,
                                              contentPadding: EdgeInsets.zero,
                                              title: Text(
                                                _taskDefinitionLabel(
                                                  item.taskDefinitionId,
                                                ),
                                              ),
                                              subtitle: Text(
                                                'Order: ${item.displayOrder ?? '—'} • Metadata: ${metadata.isEmpty ? '{}' : metadata}',
                                              ),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    item.required
                                                        ? 'Req'
                                                        : 'Opt',
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.edit,
                                                    ),
                                                    tooltip: 'Edit',
                                                    onPressed: AppEnv.isDemoMode
                                                        ? null
                                                        : () =>
                                                              _showEditProfileTaskDialog(
                                                                item,
                                                              ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.delete,
                                                    ),
                                                    tooltip: 'Delete',
                                                    onPressed: AppEnv.isDemoMode
                                                        ? null
                                                        : () =>
                                                              _deleteProfileTask(
                                                                item,
                                                              ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Task Definitions',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: _taskDefinitions.length,
                                    itemBuilder: (context, index) {
                                      final item = _taskDefinitions[index];
                                      return ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          '${item.code} • ${item.name}',
                                        ),
                                        subtitle: Text(item.category),
                                      );
                                    },
                                  ),
                                ),
                                const Divider(height: 18),
                                const Text(
                                  'Task Rules',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: _taskRules.length,
                                    itemBuilder: (context, index) {
                                      final item = _taskRules[index];
                                      return ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          _taskDefinitionLabel(
                                            item.taskDefinitionId,
                                          ),
                                        ),
                                        subtitle: Text(
                                          item.appliesWhen.isEmpty
                                              ? '{}'
                                              : item.appliesWhen.toString(),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
      case _AdminSection.jobs:
        return _buildJobsSection();
      case _AdminSection.cleaningProfiles:
        return _buildCleaningProfilesSection();
      case _AdminSection.management:
        return _buildManagementSection();
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
      case _AdminSection.knowledgeBase:
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
                child: _buildSidebar(collapsed: false, forDrawer: true),
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
                    _buildSidebar(collapsed: _sidebarCollapsed),
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

class _JobEditorFormData {
  const _JobEditorFormData({
    required this.clientId,
    required this.locationId,
    required this.scheduledDate,
    required this.scheduledStartAt,
    required this.scheduledTime,
    required this.estimatedDurationMinutes,
    this.actualDurationMinutes,
    this.cleanerEmployeeId,
  });

  final int clientId;
  final int locationId;
  final String scheduledDate;
  final String scheduledStartAt;
  final TimeOfDay scheduledTime;
  final int estimatedDurationMinutes;
  final int? actualDurationMinutes;
  final String? cleanerEmployeeId;
}

class _JobEditorDialog extends StatefulWidget {
  const _JobEditorDialog({
    required this.isCreate,
    required this.clients,
    required this.locations,
    required this.cleaners,
    this.initialClientId,
    this.initialLocationId,
    this.initialScheduledDate,
    this.initialScheduledStartAt,
    this.initialEstimatedDurationMinutes,
    this.initialActualDurationMinutes,
    this.initialCleanerEmployeeId,
    this.initialStatus,
  });

  final bool isCreate;
  final List<Client> clients;
  final List<Location> locations;
  final List<Employee> cleaners;
  final int? initialClientId;
  final int? initialLocationId;
  final DateTime? initialScheduledDate;
  final String? initialScheduledStartAt;
  final int? initialEstimatedDurationMinutes;
  final int? initialActualDurationMinutes;
  final String? initialCleanerEmployeeId;
  final String? initialStatus;

  @override
  State<_JobEditorDialog> createState() => _JobEditorDialogState();
}

class _JobEditorDialogState extends State<_JobEditorDialog> {
  int? _selectedClientId;
  int? _selectedLocationId;
  String? _selectedCleanerId;
  String? _formError;
  late DateTime _selectedDate;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  int _estimatedHours = 2;
  int _estimatedMinutesStep = 0;
  bool _includeActualDuration = false;
  int _actualHours = 0;
  int _actualMinutesStep = 0;

  @override
  void initState() {
    super.initState();
    _selectedClientId = widget.initialClientId;
    _selectedLocationId = widget.initialLocationId;
    _selectedDate =
        widget.initialScheduledDate ??
        DateTime.now().add(const Duration(days: 1));
    final estimatedMinutes = widget.initialEstimatedDurationMinutes ?? 120;
    _estimatedHours = estimatedMinutes ~/ 60;
    _estimatedMinutesStep = estimatedMinutes % 60;
    if (!DurationPickerFields.quarterHourSteps.contains(
      _estimatedMinutesStep,
    )) {
      _estimatedMinutesStep = 0;
    }
    final actualMinutes = widget.initialActualDurationMinutes;
    if (actualMinutes != null && actualMinutes >= 0) {
      _includeActualDuration = true;
      _actualHours = actualMinutes ~/ 60;
      _actualMinutesStep = actualMinutes % 60;
      if (!DurationPickerFields.quarterHourSteps.contains(_actualMinutesStep)) {
        _actualMinutesStep = 0;
      }
    }
    _selectedCleanerId = widget.initialCleanerEmployeeId;
    final cleanerExists = widget.cleaners.any(
      (cleaner) => cleaner.id == _selectedCleanerId,
    );
    if (!cleanerExists) {
      _selectedCleanerId = null;
    }
    final parsedStartAt = widget.initialScheduledStartAt == null
        ? null
        : DateTime.tryParse(widget.initialScheduledStartAt!);
    if (parsedStartAt != null) {
      final localStartAt = parsedStartAt.toLocal();
      _selectedTime = TimeOfDay(
        hour: localStartAt.hour,
        minute: localStartAt.minute,
      );
    }
    if (_selectedClientId == null && widget.clients.isNotEmpty) {
      final firstId = int.tryParse(widget.clients.first.id);
      if (firstId != null) {
        _selectedClientId = firstId;
      }
    }
    final clientExists = widget.clients.any(
      (client) => int.tryParse(client.id) == _selectedClientId,
    );
    if (!clientExists && widget.clients.isNotEmpty) {
      _selectedClientId = int.tryParse(widget.clients.first.id);
    }
    _syncLocationToClient();
  }

  List<Location> get _clientLocations {
    final selectedClientId = _selectedClientId;
    if (selectedClientId == null) return const [];
    return widget.locations
        .where((location) => location.clientId == selectedClientId)
        .toList();
  }

  void _syncLocationToClient() {
    final locations = _clientLocations;
    final selectedLocationId = _selectedLocationId;
    final hasSelected = locations.any(
      (location) => int.tryParse(location.id) == selectedLocationId,
    );
    if (!hasSelected) {
      if (locations.isEmpty) {
        _selectedLocationId = null;
      } else {
        _selectedLocationId = int.tryParse(locations.first.id);
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked == null) return;
    setState(() => _selectedTime = picked);
  }

  Future<void> _submit() async {
    final clientId = _selectedClientId;
    final locationId = _selectedLocationId;
    final estimatedDuration = (_estimatedHours * 60) + _estimatedMinutesStep;
    final actualDuration = _includeActualDuration
        ? ((_actualHours * 60) + _actualMinutesStep)
        : null;
    final initialStatus = widget.initialStatus?.trim().toLowerCase();
    if (initialStatus == 'completed' && _selectedCleanerId == null) {
      setState(() {
        _formError =
            'Completed jobs must remain assigned to a cleaner (cannot be set to None).';
      });
      return;
    }
    if (clientId == null || locationId == null || estimatedDuration <= 0) {
      setState(() {
        _formError =
            'Complete all required fields (date, client, location, estimated duration).';
      });
      return;
    }
    final selectedHour = _selectedTime.hour;
    if (selectedHour < 5 || selectedHour >= 21) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm late/early job time'),
          content: const Text(
            'This job is scheduled outside normal hours (5:00 AM - 9:00 PM). Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (!mounted) return;

    Navigator.pop(
      context,
      _JobEditorFormData(
        clientId: clientId,
        locationId: locationId,
        scheduledDate:
            '${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
        scheduledStartAt: DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime.hour,
          _selectedTime.minute,
        ).toUtc().toIso8601String(),
        scheduledTime: _selectedTime,
        estimatedDurationMinutes: estimatedDuration,
        actualDurationMinutes: actualDuration,
        cleanerEmployeeId: _selectedCleanerId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final clientLocations = _clientLocations;
    final dialogTheme = Theme.of(context).copyWith(
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? const Color(0xFF333740) : null,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF2C2F36) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: dark ? const Color(0xFF657184) : const Color(0xFFBEDCE4),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: dark ? const Color(0xFF657184) : const Color(0xFFBEDCE4),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: dark ? const Color(0xFFA8DADC) : const Color(0xFF296273),
            width: 1.4,
          ),
        ),
        labelStyle: TextStyle(
          color: dark ? const Color(0xFFE4E4E4) : const Color(0xFF442E6F),
        ),
        hintStyle: TextStyle(
          color: dark ? const Color(0xFFB8BCC4) : const Color(0xFF6A6A6A),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: dark
              ? const Color(0xFFA8DADC)
              : const Color(0xFF296273),
          side: BorderSide(
            color: dark ? const Color(0xFF657184) : const Color(0xFFBEDCE4),
          ),
        ),
      ),
    );
    return Theme(
      data: dialogTheme,
      child: AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.isCreate ? 'Create Job' : 'Edit Job',
                style: TextStyle(
                  color: dark
                      ? const Color(0xFFB39CD0)
                      : const Color(0xFF442E6F),
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '* Required fields',
                    style: TextStyle(
                      color: dark
                          ? const Color(0xFFFFC1CC)
                          : const Color(0xFF442E6F),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          'Date *: ${_selectedDate.month}-${_selectedDate.day}-${_selectedDate.year}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.access_time),
                        label: Text('Time: ${_selectedTime.format(context)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: _selectedClientId,
                  decoration: const InputDecoration(
                    labelText: 'Client *',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.clients
                      .map((client) {
                        final clientId = int.tryParse(client.id);
                        if (clientId == null) return null;
                        return DropdownMenuItem<int>(
                          value: clientId,
                          child: Text(client.name),
                        );
                      })
                      .whereType<DropdownMenuItem<int>>()
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedClientId = value;
                      _syncLocationToClient();
                    });
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: _selectedLocationId,
                  decoration: const InputDecoration(
                    labelText: 'Location *',
                    border: OutlineInputBorder(),
                  ),
                  items: clientLocations
                      .map((location) {
                        final locationId = int.tryParse(location.id);
                        if (locationId == null) return null;
                        final line = location.address?.trim().isNotEmpty == true
                            ? location.address!.trim()
                            : location.locationNumber;
                        return DropdownMenuItem<int>(
                          value: locationId,
                          child: Text(line),
                        );
                      })
                      .whereType<DropdownMenuItem<int>>()
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedLocationId = value),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  initialValue: _selectedCleanerId,
                  decoration: const InputDecoration(
                    labelText: 'Cleaner',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('None (Pending)'),
                    ),
                    ...widget.cleaners.map(
                      (cleaner) => DropdownMenuItem<String?>(
                        value: cleaner.id,
                        child: Text(cleaner.name),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedCleanerId = value),
                ),
                const SizedBox(height: 10),
                DurationPickerFields(
                  label: 'Estimated Duration *',
                  hours: _estimatedHours,
                  minutesStep: _estimatedMinutesStep,
                  onHoursChanged: (value) =>
                      setState(() => _estimatedHours = value),
                  onMinutesChanged: (value) =>
                      setState(() => _estimatedMinutesStep = value),
                ),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include Actual Duration'),
                  value: _includeActualDuration,
                  onChanged: (value) =>
                      setState(() => _includeActualDuration = value),
                ),
                if (_includeActualDuration)
                  DurationPickerFields(
                    label: 'Actual Duration',
                    hours: _actualHours,
                    minutesStep: _actualMinutesStep,
                    onHoursChanged: (value) =>
                        setState(() => _actualHours = value),
                    onMinutesChanged: (value) =>
                        setState(() => _actualMinutesStep = value),
                  ),
                if (_formError != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _formError!,
                      style: TextStyle(
                        color: dark
                            ? const Color(0xFFFFC1CC)
                            : const Color(0xFFE63721),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
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
            onPressed: _submit,
            child: Text(widget.isCreate ? 'Create' : 'Save'),
          ),
        ],
      ),
    );
  }
}

class _EmployeeEditorDialog extends StatefulWidget {
  const _EmployeeEditorDialog({
    this.employeeNumber = '',
    this.status = 'invited',
    this.name = '',
    this.email = '',
    this.phoneNumber = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.zipCode = '',
    this.photoUrl = '',
    this.isCreate = true,
  });

  final String employeeNumber;
  final String status;
  final String name;
  final String email;
  final String phoneNumber;
  final String address;
  final String city;
  final String state;
  final String zipCode;
  final String photoUrl;
  final bool isCreate;

  @override
  State<_EmployeeEditorDialog> createState() => _EmployeeEditorDialogState();
}

class _EmployeeEditorDialogState extends State<_EmployeeEditorDialog> {
  static const String _defaultEmployeePhotoAsset =
      '/assets/images/profiles/employee_default.png';
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _zipCode;
  late final TextEditingController _photoUrl;
  late String _status;

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
    _photoUrl = TextEditingController(text: widget.photoUrl);
    _status = widget.status.trim().isEmpty
        ? 'invited'
        : widget.status.trim().toLowerCase();
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
    _photoUrl.dispose();
    super.dispose();
  }

  String _assetPath(String? value, {required String fallback}) {
    final candidate = (value == null || value.trim().isEmpty)
        ? fallback
        : value.trim();
    return candidate.startsWith('/') ? candidate.substring(1) : candidate;
  }

  Future<void> _editPhotoPath() async {
    final controller = TextEditingController(text: _photoUrl.text);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Employee photo path'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Asset path',
            hintText: '/assets/images/profiles/employee_default.png',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (value == null) return;
    setState(() {
      _photoUrl.text = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              widget.isCreate ? 'Create Employee' : 'Edit Employee',
              style: TextStyle(
                color: dark ? const Color(0xFFB39CD0) : const Color(0xFF442E6F),
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
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _photoUrl,
                builder: (context, value, _) {
                  final path = value.text.trim().isNotEmpty
                      ? value.text.trim()
                      : _defaultEmployeePhotoAsset;
                  return Stack(
                    children: [
                      CircleAvatar(
                        radius: 56,
                        backgroundColor: dark
                            ? const Color(0xFF3B4250)
                            : const Color(0xFFA8D6F7),
                        backgroundImage: AssetImage(
                          _assetPath(
                            path,
                            fallback: _defaultEmployeePhotoAsset,
                          ),
                        ),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Edit photo path',
                          onPressed: _editPhotoPath,
                          icon: const Icon(Icons.edit, size: 18),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    '* Required fields',
                    style: TextStyle(
                      color: dark
                          ? const Color(0xFFFFC1CC)
                          : const Color(0xFF442E6F),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Employee #: ${widget.employeeNumber.isEmpty ? '—' : widget.employeeNumber}',
                    style: TextStyle(
                      color: dark
                          ? const Color(0xFFE4E4E4)
                          : const Color(0xFF41588E),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _field(_name, 'Name', required: true),
              const SizedBox(height: 10),
              _field(_email, 'Email', required: true),
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
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'invited', child: Text('Invited')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                  DropdownMenuItem(value: 'resigned', child: Text('Resigned')),
                  DropdownMenuItem(value: 'deleted', child: Text('Deleted')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _status = value);
                },
              ),
              if (widget.isCreate)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'New employees default to the shared profile image unless changed above.',
                      style: TextStyle(
                        fontSize: 12,
                        color: dark
                            ? const Color(0xFFE4E4E4)
                            : const Color(0xFF41588E),
                      ),
                    ),
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
                  photoUrl: _nullable(_photoUrl.text),
                  status: _status,
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
                  photoUrl: _nullable(_photoUrl.text),
                  status: _status,
                ),
              );
            }
          },
          child: Text(widget.isCreate ? 'Create' : 'Save'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
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
    this.status = 'active',
    this.email = '',
    this.phoneNumber = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.zipCode = '',
    this.preferredContactMethod = '',
    this.preferredContactWindow = '',
    this.isCreate = true,
  });

  final String name;
  final String status;
  final String email;
  final String phoneNumber;
  final String address;
  final String city;
  final String state;
  final String zipCode;
  final String preferredContactMethod;
  final String preferredContactWindow;
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
  late final TextEditingController _preferredContactWindow;
  late String _preferredContactMethod;
  late String _status;

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
    _preferredContactWindow = TextEditingController(
      text: widget.preferredContactWindow,
    );
    _preferredContactMethod = widget.preferredContactMethod.trim().isEmpty
        ? 'phone'
        : widget.preferredContactMethod.trim().toLowerCase();
    _status = widget.status.trim().isEmpty
        ? 'active'
        : widget.status.trim().toLowerCase();
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
    _preferredContactWindow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              widget.isCreate ? 'Create Client' : 'Edit Client',
              style: TextStyle(
                color: dark ? const Color(0xFFB39CD0) : const Color(0xFF442E6F),
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
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '* Required fields',
                  style: TextStyle(
                    color: dark
                        ? const Color(0xFFFFC1CC)
                        : const Color(0xFF442E6F),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _field(_name, 'Name', required: true),
              const SizedBox(height: 10),
              _field(_email, 'Email', required: true),
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
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'invited', child: Text('Invited')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                  DropdownMenuItem(value: 'deleted', child: Text('Deleted')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _status = value);
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _preferredContactMethod,
                decoration: const InputDecoration(
                  labelText: 'Preferred Contact Method',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'phone', child: Text('Phone')),
                  DropdownMenuItem(value: 'email', child: Text('Email')),
                  DropdownMenuItem(value: 'sms', child: Text('SMS')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _preferredContactMethod = value);
                },
              ),
              const SizedBox(height: 10),
              _field(_preferredContactWindow, 'Preferred Contact Window'),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2F313A)
                      : const Color(0xFFEAF4FA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF4A4D5A)
                        : const Color(0xFFA8D6F7),
                  ),
                ),
                child: const Text(
                  'Coordinates are auto-filled from address on save when not provided.',
                  style: TextStyle(fontSize: 12),
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
            if (widget.isCreate) {
              if (_name.text.trim().isEmpty || _email.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(
                context,
                ClientCreateInput(
                  name: _name.text.trim(),
                  email: _email.text.trim(),
                  status: _status,
                  phoneNumber: _nullable(_phone.text),
                  address: _nullable(_address.text),
                  city: _nullable(_city.text),
                  state: _nullable(_state.text),
                  zipCode: _nullable(_zipCode.text),
                  preferredContactMethod: _nullable(_preferredContactMethod),
                  preferredContactWindow: _nullable(
                    _preferredContactWindow.text,
                  ),
                ),
              );
            } else {
              Navigator.pop(
                context,
                ClientUpdateInput(
                  name: _nullable(_name.text),
                  email: _nullable(_email.text),
                  status: _status,
                  phoneNumber: _nullable(_phone.text),
                  address: _nullable(_address.text),
                  city: _nullable(_city.text),
                  state: _nullable(_state.text),
                  zipCode: _nullable(_zipCode.text),
                  preferredContactMethod: _nullable(_preferredContactMethod),
                  preferredContactWindow: _nullable(
                    _preferredContactWindow.text,
                  ),
                ),
              );
            }
          },
          child: Text(widget.isCreate ? 'Create' : 'Save'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
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
    this.status = 'active',
    this.type = 'residential',
    this.photoUrl = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.zipCode = '',
    this.isCreate = true,
  });

  final List<Client> clients;
  final int? clientId;
  final String status;
  final String type;
  final String photoUrl;
  final String address;
  final String city;
  final String state;
  final String zipCode;
  final bool isCreate;

  @override
  State<_LocationEditorDialog> createState() => _LocationEditorDialogState();
}

class _LocationEditorDialogState extends State<_LocationEditorDialog> {
  static const String _defaultLocationPhotoAsset =
      '/assets/images/locations/location_default.png';
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _zipCode;
  late final TextEditingController _photoUrl;
  late String _type;
  late String _status;
  int? _selectedClientId;

  @override
  void initState() {
    super.initState();
    _address = TextEditingController(text: widget.address);
    _city = TextEditingController(text: widget.city);
    _state = TextEditingController(text: widget.state);
    _zipCode = TextEditingController(text: widget.zipCode);
    _photoUrl = TextEditingController(text: widget.photoUrl);
    _type = widget.type.toLowerCase();
    _status = widget.status.trim().isEmpty
        ? 'active'
        : widget.status.trim().toLowerCase();
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
    _photoUrl.dispose();
    super.dispose();
  }

  String _assetPath(String? value, {required String fallback}) {
    final candidate = (value == null || value.trim().isEmpty)
        ? fallback
        : value.trim();
    return candidate.startsWith('/') ? candidate.substring(1) : candidate;
  }

  Future<void> _editPhotoPath() async {
    final controller = TextEditingController(text: _photoUrl.text);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location photo path'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Asset path',
            hintText: '/assets/images/locations/location_default.png',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (value == null) return;
    setState(() => _photoUrl.text = value);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              widget.isCreate ? 'Create Location' : 'Edit Location',
              style: TextStyle(
                color: dark ? const Color(0xFFB39CD0) : const Color(0xFF442E6F),
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
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _photoUrl,
                builder: (context, value, _) {
                  final path = value.text.trim().isNotEmpty
                      ? value.text.trim()
                      : _defaultLocationPhotoAsset;
                  return Stack(
                    children: [
                      CircleAvatar(
                        radius: 56,
                        backgroundColor: dark
                            ? const Color(0xFF3B4250)
                            : const Color(0xFFA8D6F7),
                        backgroundImage: AssetImage(
                          _assetPath(
                            path,
                            fallback: _defaultLocationPhotoAsset,
                          ),
                        ),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Edit location photo',
                          onPressed: _editPhotoPath,
                          icon: const Icon(Icons.edit, size: 18),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '* Required fields',
                  style: TextStyle(
                    color: dark
                        ? const Color(0xFFFFC1CC)
                        : const Color(0xFF442E6F),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (widget.isCreate)
                DropdownButtonFormField<int>(
                  initialValue: _selectedClientId,
                  decoration: const InputDecoration(
                    labelText: 'Client *',
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
                  labelText: 'Type *',
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
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                  DropdownMenuItem(value: 'deleted', child: Text('Deleted')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _status = value);
                },
              ),
              const SizedBox(height: 10),
              _field(_address, 'Address', required: true),
              const SizedBox(height: 10),
              _field(_city, 'City', required: true),
              const SizedBox(height: 10),
              _field(_state, 'State', required: true),
              const SizedBox(height: 10),
              _field(_zipCode, 'Zip Code', required: true),
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
                  status: _status,
                  clientId: _selectedClientId!,
                  photoUrl: _nullable(_photoUrl.text),
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
                  status: _status,
                  photoUrl: _nullable(_photoUrl.text),
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

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _CleaningProfileEditorDialog extends StatefulWidget {
  const _CleaningProfileEditorDialog({
    required this.locations,
    this.isCreate = true,
    this.selectedLocationId,
    this.name = '',
    this.notes = '',
  });

  final List<Location> locations;
  final bool isCreate;
  final int? selectedLocationId;
  final String name;
  final String notes;

  @override
  State<_CleaningProfileEditorDialog> createState() =>
      _CleaningProfileEditorDialogState();
}

class _CleaningProfileEditorDialogState
    extends State<_CleaningProfileEditorDialog> {
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
    return AlertDialog(
      title: Text(
        widget.isCreate ? 'Create Cleaning Profile' : 'Edit Cleaning Profile',
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
                  notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
                ),
              );
            } else {
              Navigator.pop(
                context,
                CleaningProfileUpdateInput(
                  locationId: _selectedLocationId!,
                  name: _name.text.trim(),
                  notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
                ),
              );
            }
          },
          child: Text(widget.isCreate ? 'Create' : 'Save'),
        ),
      ],
    );
  }
}

class _TaskDefinitionEditorDialog extends StatefulWidget {
  const _TaskDefinitionEditorDialog();

  @override
  State<_TaskDefinitionEditorDialog> createState() =>
      _TaskDefinitionEditorDialogState();
}

class _TaskDefinitionEditorDialogState
    extends State<_TaskDefinitionEditorDialog> {
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

class _TaskRuleEditorDialog extends StatefulWidget {
  const _TaskRuleEditorDialog({required this.taskDefinitions});

  final List<TaskDefinition> taskDefinitions;

  @override
  State<_TaskRuleEditorDialog> createState() => _TaskRuleEditorDialogState();
}

class _TaskRuleEditorDialogState extends State<_TaskRuleEditorDialog> {
  late final TextEditingController _appliesWhen;
  late final TextEditingController _displayOrder;
  late final TextEditingController _notesTemplate;
  bool _required = true;
  int? _selectedTaskDefinitionId;

  @override
  void initState() {
    super.initState();
    _appliesWhen = TextEditingController(text: '{}');
    _displayOrder = TextEditingController();
    _notesTemplate = TextEditingController();
    _selectedTaskDefinitionId = int.tryParse(widget.taskDefinitions.first.id);
  }

  @override
  void dispose() {
    _appliesWhen.dispose();
    _displayOrder.dispose();
    _notesTemplate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Task Rule'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _selectedTaskDefinitionId,
                decoration: const InputDecoration(
                  labelText: 'Task Definition',
                  border: OutlineInputBorder(),
                ),
                items: widget.taskDefinitions
                    .map(
                      (task) => DropdownMenuItem<int>(
                        value: int.tryParse(task.id),
                        child: Text('${task.code} • ${task.name}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedTaskDefinitionId = value),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _appliesWhen,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Applies When JSON',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _displayOrder,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Display Order (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notesTemplate,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes Template (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 6),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _required,
                title: const Text('Required'),
                onChanged: (value) => setState(() => _required = value ?? true),
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
            if (_selectedTaskDefinitionId == null) return;
            final applies = _parseAppliesWhen(_appliesWhen.text);
            if (applies == null) return;
            Navigator.pop(
              context,
              TaskRuleCreateInput(
                taskDefinitionId: _selectedTaskDefinitionId!,
                appliesWhen: applies,
                required: _required,
                displayOrder: int.tryParse(_displayOrder.text.trim()),
                notesTemplate: _notesTemplate.text.trim().isEmpty
                    ? null
                    : _notesTemplate.text.trim(),
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }

  Map<String, dynamic>? _parseAppliesWhen(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return {};
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}

class _ProfileTaskEditorDialog extends StatefulWidget {
  const _ProfileTaskEditorDialog({
    required this.taskDefinitions,
    this.isCreate = true,
    this.selectedTaskDefinitionId,
    this.requiredValue = true,
    this.displayOrderValue,
    this.taskMetadataValue = const {},
  });

  final List<TaskDefinition> taskDefinitions;
  final bool isCreate;
  final int? selectedTaskDefinitionId;
  final bool requiredValue;
  final int? displayOrderValue;
  final Map<String, dynamic> taskMetadataValue;

  @override
  State<_ProfileTaskEditorDialog> createState() =>
      _ProfileTaskEditorDialogState();
}

class _ProfileTaskEditorDialogState extends State<_ProfileTaskEditorDialog> {
  late final TextEditingController _displayOrder;
  late final TextEditingController _taskMetadata;
  late bool _required;
  int? _selectedTaskDefinitionId;

  @override
  void initState() {
    super.initState();
    _displayOrder = TextEditingController(
      text: widget.displayOrderValue?.toString() ?? '',
    );
    _taskMetadata = TextEditingController(
      text: widget.taskMetadataValue.isEmpty
          ? '{}'
          : jsonEncode(widget.taskMetadataValue),
    );
    _required = widget.requiredValue;
    _selectedTaskDefinitionId =
        widget.selectedTaskDefinitionId ??
        int.tryParse(widget.taskDefinitions.first.id);
  }

  @override
  void dispose() {
    _displayOrder.dispose();
    _taskMetadata.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isCreate ? 'Link Profile Task' : 'Edit Profile Task'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _selectedTaskDefinitionId,
                decoration: const InputDecoration(
                  labelText: 'Task Definition',
                  border: OutlineInputBorder(),
                ),
                items: widget.taskDefinitions
                    .map(
                      (task) => DropdownMenuItem<int>(
                        value: int.tryParse(task.id),
                        child: Text('${task.code} • ${task.name}'),
                      ),
                    )
                    .toList(),
                onChanged: widget.isCreate
                    ? (value) =>
                          setState(() => _selectedTaskDefinitionId = value)
                    : null,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _displayOrder,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Display Order (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _taskMetadata,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Task Metadata JSON',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 6),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _required,
                title: const Text('Required'),
                onChanged: (value) => setState(() => _required = value ?? true),
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
            final metadata = _parseMetadata(_taskMetadata.text);
            if (metadata == null) return;
            if (widget.isCreate) {
              if (_selectedTaskDefinitionId == null) return;
              Navigator.pop(
                context,
                ProfileTaskCreateInput(
                  taskDefinitionId: _selectedTaskDefinitionId!,
                  required: _required,
                  displayOrder: int.tryParse(_displayOrder.text.trim()),
                  taskMetadata: metadata,
                ),
              );
              return;
            }
            Navigator.pop(
              context,
              ProfileTaskUpdateInput(
                required: _required,
                displayOrder: int.tryParse(_displayOrder.text.trim()),
                taskMetadata: metadata,
              ),
            );
          },
          child: Text(widget.isCreate ? 'Link' : 'Save'),
        ),
      ],
    );
  }

  Map<String, dynamic>? _parseMetadata(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return {};
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
