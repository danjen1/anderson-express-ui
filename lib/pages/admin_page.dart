import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/backend_config.dart';
import '../models/cleaning_profile.dart';
import '../models/client.dart';
import '../models/employee.dart';
import '../models/job.dart';
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
import '../widgets/demo_mode_notice.dart';
import '../widgets/profile_menu_button.dart';
import '../widgets/theme_toggle_button.dart';

enum _AdminSection {
  dashboard,
  jobs,
  cleaningProfiles,
  clients,
  employees,
  locations,
  reports,
  knowledgeBase,
}

enum _EmployeeFilter { all, active, inactive }

enum _ClientFilter { all, active, inactive }

enum _LocationFilter { all, active, inactive }

enum _JobFilter { all, pending, assigned, inProgress, completed, overdue }

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
  List<CleaningProfile> _cleaningProfiles = const [];
  List<TaskDefinition> _taskDefinitions = const [];
  List<TaskRule> _taskRules = const [];
  List<ProfileTask> _selectedProfileTasks = const [];
  _AdminSection _selectedSection = _AdminSection.dashboard;
  _EmployeeFilter _employeeFilter = _EmployeeFilter.active;
  _ClientFilter _clientFilter = _ClientFilter.active;
  _LocationFilter _locationFilter = _LocationFilter.active;
  _JobFilter _jobFilter = _JobFilter.pending;
  String? _selectedCleaningProfileId;
  bool _loadingProfileTasks = false;

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
      final employeesFuture = _api.listEmployees(bearerToken: token);
      final jobsFuture = _api.listJobs(bearerToken: token);
      final clientsFuture = _api.listClients(bearerToken: token);
      final locationsFuture = _api.listLocations(bearerToken: token);
      final profilesFuture = _api.listCleaningProfiles(bearerToken: token);
      final taskDefsFuture = _api.listTaskDefinitions(bearerToken: token);
      final taskRulesFuture = _api.listTaskRules(bearerToken: token);
      final results = await Future.wait([
        employeesFuture,
        jobsFuture,
        clientsFuture,
        locationsFuture,
        profilesFuture,
        taskDefsFuture,
        taskRulesFuture,
      ]);
      final employees = results[0] as List<Employee>;
      final jobs = results[1] as List<Job>;
      final clients = results[2] as List<Client>;
      final locations = results[3] as List<Location>;
      final profiles = results[4] as List<CleaningProfile>;
      final taskDefinitions = results[5] as List<TaskDefinition>;
      final taskRules = results[6] as List<TaskRule>;
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

  Future<void> _showCreateJobDialog() async {
    if (AppEnv.isDemoMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo mode: create/edit/delete actions are disabled'),
        ),
      );
      return;
    }
    if (_locations.isEmpty || _cleaningProfiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Create at least one location and cleaning profile before creating a job.',
          ),
        ),
      );
      return;
    }

    final result = await showDialog<JobCreateInput>(
      context: context,
      builder: (context) => _JobEditorDialog(
        locations: _locations,
        cleaningProfiles: _cleaningProfiles,
      ),
    );
    if (result == null) return;

    try {
      await _api.createJob(result, bearerToken: _token);
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
    if (AppEnv.isDemoMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo mode: create/edit/delete actions are disabled'),
        ),
      );
      return;
    }
    if (_cleaningProfiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a cleaning profile first')),
      );
      return;
    }

    final result = await showDialog<JobUpdateInput>(
      context: context,
      builder: (context) => _JobEditorDialog(
        locations: _locations,
        cleaningProfiles: _cleaningProfiles,
        isCreate: false,
        selectedProfileId: job.profileId,
        scheduledDate: formatDateMdy(job.scheduledDate),
        status: job.status.toLowerCase(),
        notes: job.notes ?? '',
      ),
    );
    if (result == null) return;

    try {
      await _api.updateJob(job.id, result, bearerToken: _token);
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
        title: const Text('Delete job'),
        content: Text('Delete ${job.jobNumber}?'),
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
    if (AppEnv.isDemoMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo mode: create/edit/delete actions are disabled'),
        ),
      );
      return;
    }
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
    if (AppEnv.isDemoMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo mode: create/edit/delete actions are disabled'),
        ),
      );
      return;
    }
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
    if (AppEnv.isDemoMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo mode: create/edit/delete actions are disabled'),
        ),
      );
      return;
    }
    final result = await showDialog<TaskDefinitionCreateInput>(
      context: context,
      builder: (context) => const _TaskDefinitionEditorDialog(),
    );
    if (result == null) return;

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
    if (AppEnv.isDemoMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo mode: create/edit/delete actions are disabled'),
        ),
      );
      return;
    }
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

  String _locationLabel(int locationId) {
    for (final location in _locations) {
      if (int.tryParse(location.id) == locationId) {
        return location.locationNumber;
      }
    }
    return 'Location $locationId';
  }

  String _profileLabel(int profileId) {
    for (final profile in _cleaningProfiles) {
      if (int.tryParse(profile.id) == profileId) {
        return profile.name;
      }
    }
    return 'Profile $profileId';
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

  Widget _centeredSectionBody(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1240),
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

  void _openJobsOverdue() {
    setState(() {
      _selectedSection = _AdminSection.jobs;
      _jobFilter = _JobFilter.overdue;
    });
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
                    Chip(label: Text('Operations Summary (Stub)')),
                    Chip(label: Text('Payroll Window Export (Stub)')),
                    Chip(label: Text('Client Service Recap (Stub)')),
                  ],
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
        Expanded(
          child: _centeredSectionBody(
            Column(
              children: [
                Row(
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Active'),
                          selected: _employeeFilter == _EmployeeFilter.active,
                          onSelected: (_) => setState(
                            () => _employeeFilter = _EmployeeFilter.active,
                          ),
                        ),
                        ChoiceChip(
                          label: const Text('Inactive'),
                          selected: _employeeFilter == _EmployeeFilter.inactive,
                          onSelected: (_) => setState(
                            () => _employeeFilter = _EmployeeFilter.inactive,
                          ),
                        ),
                        ChoiceChip(
                          label: const Text('All'),
                          selected: _employeeFilter == _EmployeeFilter.all,
                          onSelected: (_) => setState(
                            () => _employeeFilter = _EmployeeFilter.all,
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
                          columns: [
                            _tableColumn('Employee #'),
                            _tableColumn('Name'),
                            _tableColumn('Status'),
                            _tableColumn('Email'),
                            _tableColumn('Phone'),
                            _tableColumn('Actions'),
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
                                                : () =>
                                                      _showEditDialog(employee),
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
        Expanded(
          child: _centeredSectionBody(
            Column(
              children: [
                Row(
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Active'),
                          selected: _clientFilter == _ClientFilter.active,
                          onSelected: (_) => setState(
                            () => _clientFilter = _ClientFilter.active,
                          ),
                        ),
                        ChoiceChip(
                          label: const Text('Inactive'),
                          selected: _clientFilter == _ClientFilter.inactive,
                          onSelected: (_) => setState(
                            () => _clientFilter = _ClientFilter.inactive,
                          ),
                        ),
                        ChoiceChip(
                          label: const Text('All'),
                          selected: _clientFilter == _ClientFilter.all,
                          onSelected: (_) =>
                              setState(() => _clientFilter = _ClientFilter.all),
                        ),
                      ],
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: AppEnv.isDemoMode
                          ? null
                          : _showCreateClientDialog,
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
                          columns: [
                            _tableColumn('Client #'),
                            _tableColumn('Name'),
                            _tableColumn('Status'),
                            _tableColumn('Email'),
                            _tableColumn('Phone'),
                            _tableColumn('Actions'),
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
                                                : () => _showEditClientDialog(
                                                    client,
                                                  ),
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
        Expanded(
          child: _centeredSectionBody(
            Column(
              children: [
                Row(
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Active'),
                          selected: _locationFilter == _LocationFilter.active,
                          onSelected: (_) => setState(
                            () => _locationFilter = _LocationFilter.active,
                          ),
                        ),
                        ChoiceChip(
                          label: const Text('Inactive'),
                          selected: _locationFilter == _LocationFilter.inactive,
                          onSelected: (_) => setState(
                            () => _locationFilter = _LocationFilter.inactive,
                          ),
                        ),
                        ChoiceChip(
                          label: const Text('All'),
                          selected: _locationFilter == _LocationFilter.all,
                          onSelected: (_) => setState(
                            () => _locationFilter = _LocationFilter.all,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: AppEnv.isDemoMode
                          ? null
                          : _showCreateLocationDialog,
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
                          columns: [
                            _tableColumn('Photo'),
                            _tableColumn('Client'),
                            _tableColumn('Type'),
                            _tableColumn('Status'),
                            _tableColumn('Address'),
                            _tableColumn('Actions'),
                          ],
                          rows: rows
                              .map(
                                (location) => DataRow(
                                  cells: [
                                    const DataCell(
                                      CircleAvatar(
                                        radius: 14,
                                        child: Icon(Icons.photo, size: 16),
                                      ),
                                    ),
                                    DataCell(
                                      Text(_clientNameById(location.clientId)),
                                    ),
                                    DataCell(Text(location.type)),
                                    DataCell(Text(location.status)),
                                    DataCell(
                                      Text(
                                        [
                                              location.address ?? '',
                                              location.city ?? '',
                                              location.state ?? '',
                                              location.zipCode ?? '',
                                            ]
                                            .where((e) => e.trim().isNotEmpty)
                                            .join(', '),
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
                                                : () => _showEditLocationDialog(
                                                    location,
                                                  ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete),
                                            tooltip: 'Delete',
                                            onPressed: AppEnv.isDemoMode
                                                ? null
                                                : () =>
                                                      _deleteLocation(location),
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
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJobsSection() {
    final rows = _filteredJobs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Jobs',
          'Create jobs, link location + cleaning profile, and monitor status.',
        ),
        Expanded(
          child: _centeredSectionBody(
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Pending'),
                            selected: _jobFilter == _JobFilter.pending,
                            onSelected: (_) =>
                                setState(() => _jobFilter = _JobFilter.pending),
                          ),
                          ChoiceChip(
                            label: const Text('Assigned'),
                            selected: _jobFilter == _JobFilter.assigned,
                            onSelected: (_) => setState(
                              () => _jobFilter = _JobFilter.assigned,
                            ),
                          ),
                          ChoiceChip(
                            label: const Text('In Progress'),
                            selected: _jobFilter == _JobFilter.inProgress,
                            onSelected: (_) => setState(
                              () => _jobFilter = _JobFilter.inProgress,
                            ),
                          ),
                          ChoiceChip(
                            label: const Text('Completed'),
                            selected: _jobFilter == _JobFilter.completed,
                            onSelected: (_) => setState(
                              () => _jobFilter = _JobFilter.completed,
                            ),
                          ),
                          ChoiceChip(
                            label: const Text('Overdue'),
                            selected: _jobFilter == _JobFilter.overdue,
                            onSelected: (_) =>
                                setState(() => _jobFilter = _JobFilter.overdue),
                          ),
                          ChoiceChip(
                            label: const Text('All'),
                            selected: _jobFilter == _JobFilter.all,
                            onSelected: (_) =>
                                setState(() => _jobFilter = _JobFilter.all),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/jobs'),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open Jobs Route'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: AppEnv.isDemoMode
                          ? null
                          : _showCreateJobDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Create Job'),
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
                          columns: [
                            _tableColumn('Job #'),
                            _tableColumn('Client'),
                            _tableColumn('Status'),
                            _tableColumn('Scheduled'),
                            _tableColumn('Location'),
                            _tableColumn('Cleaning Profile'),
                            _tableColumn('Actions'),
                          ],
                          rows: rows
                              .map(
                                (job) => DataRow(
                                  cells: [
                                    DataCell(Text(job.jobNumber)),
                                    DataCell(Text(job.clientName ?? '—')),
                                    DataCell(Text(job.status)),
                                    DataCell(
                                      Text(formatDateMdy(job.scheduledDate)),
                                    ),
                                    DataCell(
                                      Text(_locationLabel(job.locationId)),
                                    ),
                                    DataCell(
                                      Text(_profileLabel(job.profileId)),
                                    ),
                                    DataCell(
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit),
                                            tooltip: 'Edit',
                                            onPressed: AppEnv.isDemoMode
                                                ? null
                                                : () => _showEditJobDialog(job),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete),
                                            tooltip: 'Delete',
                                            onPressed: AppEnv.isDemoMode
                                                ? null
                                                : () => _deleteJob(job),
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
            ),
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
              onPressed: AppEnv.isDemoMode
                  ? null
                  : _showCreateCleaningProfileDialog,
              icon: const Icon(Icons.add_task),
              label: const Text('Create Profile'),
            ),
            OutlinedButton.icon(
              onPressed: AppEnv.isDemoMode
                  ? null
                  : _showCreateTaskDefinitionDialog,
              icon: const Icon(Icons.playlist_add),
              label: const Text('Create Task Definition'),
            ),
            OutlinedButton.icon(
              onPressed: AppEnv.isDemoMode ? null : _showCreateTaskRuleDialog,
              icon: const Icon(Icons.rule),
              label: const Text('Create Task Rule'),
            ),
            FilledButton.icon(
              onPressed: AppEnv.isDemoMode ? null : _showAddProfileTaskDialog,
              icon: const Icon(Icons.link),
              label: const Text('Link Task To Selected Profile'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _centeredSectionBody(
            Row(
              children: [
                Expanded(
                  flex: 3,
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
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Expanded(
                        flex: 2,
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
                      const SizedBox(height: 12),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Task Definitions',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Expanded(
                                        child: ListView.builder(
                                          itemCount: _taskDefinitions.length,
                                          itemBuilder: (context, index) {
                                            final item =
                                                _taskDefinitions[index];
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
                                    ],
                                  ),
                                ),
                                const VerticalDivider(),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Task Rules',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
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
                                                    : item.appliesWhen
                                                          .toString(),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
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
      case _AdminSection.employees:
        return _buildEmployeesSection();
      case _AdminSection.jobs:
        return _buildJobsSection();
      case _AdminSection.cleaningProfiles:
        return _buildCleaningProfilesSection();
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
    final adminTheme = baseTheme.copyWith(
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color.fromRGBO(41, 98, 255, 1),
          foregroundColor: Colors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color.fromRGBO(31, 63, 122, 1),
          side: const BorderSide(color: Color.fromRGBO(106, 142, 214, 1)),
        ),
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        backgroundColor: const Color.fromRGBO(238, 243, 252, 1),
        selectedColor: const Color.fromRGBO(205, 220, 246, 1),
        side: const BorderSide(color: Color.fromRGBO(154, 181, 228, 1)),
        labelStyle: const TextStyle(
          color: Color.fromRGBO(31, 63, 122, 1),
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anderson Express Cleaning Service'),
        bottom: const BackendBanner(),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            onPressed: _loading ? null : _loadAdminData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          const ProfileMenuButton(),
        ],
      ),
      body: Theme(
        data: adminTheme,
        child: SelectionArea(
          child: Row(
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
        ),
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

class _JobEditorDialog extends StatefulWidget {
  const _JobEditorDialog({
    required this.locations,
    required this.cleaningProfiles,
    this.isCreate = true,
    this.selectedProfileId,
    this.scheduledDate = '',
    this.status = 'pending',
    this.notes = '',
  });

  final List<Location> locations;
  final List<CleaningProfile> cleaningProfiles;
  final bool isCreate;
  final int? selectedProfileId;
  final String scheduledDate;
  final String status;
  final String notes;

  @override
  State<_JobEditorDialog> createState() => _JobEditorDialogState();
}

class _JobEditorDialogState extends State<_JobEditorDialog> {
  late final TextEditingController _scheduledDate;
  late final TextEditingController _notes;
  int? _selectedLocationId;
  int? _selectedProfileId;
  late String _status;

  @override
  void initState() {
    super.initState();
    _scheduledDate = TextEditingController(
      text: widget.scheduledDate.isNotEmpty
          ? widget.scheduledDate
          : DateTime.now().toIso8601String().split('T').first,
    );
    _notes = TextEditingController(text: widget.notes);
    _selectedLocationId = int.tryParse(widget.locations.first.id);
    _selectedProfileId =
        widget.selectedProfileId ??
        int.tryParse(widget.cleaningProfiles.first.id);
    _status = widget.status;
  }

  @override
  void dispose() {
    _scheduledDate.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isCreate ? 'Create Job' : 'Edit Job'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isCreate)
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
                          child: Text(
                            '${location.locationNumber} • ${location.type}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedLocationId = value),
                ),
              if (widget.isCreate) const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: _selectedProfileId,
                decoration: const InputDecoration(
                  labelText: 'Cleaning Profile',
                  border: OutlineInputBorder(),
                ),
                items: widget.cleaningProfiles
                    .map(
                      (profile) => DropdownMenuItem<int>(
                        value: int.tryParse(profile.id),
                        child: Text(profile.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedProfileId = value),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _scheduledDate,
                decoration: const InputDecoration(
                  labelText: 'Scheduled Date (YYYY-MM-DD or M-D-YYYY)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (!widget.isCreate) const SizedBox(height: 10),
              if (!widget.isCreate)
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(
                      value: 'assigned',
                      child: Text('Assigned'),
                    ),
                    DropdownMenuItem(
                      value: 'in_progress',
                      child: Text('In Progress'),
                    ),
                    DropdownMenuItem(
                      value: 'completed',
                      child: Text('Completed'),
                    ),
                    DropdownMenuItem(
                      value: 'canceled',
                      child: Text('Canceled'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _status = value);
                  },
                ),
              if (!widget.isCreate) const SizedBox(height: 10),
              if (!widget.isCreate)
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
            if (_selectedProfileId == null) {
              return;
            }
            final normalized = _normalizeDate(_scheduledDate.text);
            if (normalized == null) {
              return;
            }
            if (widget.isCreate) {
              if (_selectedLocationId == null) return;
              Navigator.pop(
                context,
                JobCreateInput(
                  profileId: _selectedProfileId!,
                  locationId: _selectedLocationId!,
                  scheduledDate: normalized,
                ),
              );
            } else {
              Navigator.pop(
                context,
                JobUpdateInput(
                  profileId: _selectedProfileId!,
                  scheduledDate: normalized,
                  status: _status,
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

  String? _normalizeDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final parsed = parseFlexibleDate(trimmed);
    if (parsed != null) {
      final yyyy = parsed.year.toString().padLeft(4, '0');
      final mm = parsed.month.toString().padLeft(2, '0');
      final dd = parsed.day.toString().padLeft(2, '0');
      return '$yyyy-$mm-$dd';
    }

    final parts = trimmed.split('-');
    if (parts.length != 3) return null;
    final month = int.tryParse(parts[0]);
    final day = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (month == null || day == null || year == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31 || year < 2000) {
      return null;
    }
    final yyyy = year.toString().padLeft(4, '0');
    final mm = month.toString().padLeft(2, '0');
    final dd = day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
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
