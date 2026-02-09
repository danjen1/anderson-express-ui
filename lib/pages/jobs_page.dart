import 'package:flutter/material.dart';

import '../mixins/base_api_page_mixin.dart';
import '../models/backend_config.dart';
import '../models/employee.dart';
import '../models/job.dart';
import '../models/job_assignment.dart';
import '../models/job_task.dart';
import '../services/app_env.dart';
import '../services/auth_session.dart';
import '../services/backend_runtime.dart';
import '../utils/error_text.dart';
import '../widgets/backend_banner.dart';
import '../widgets/brand_app_bar_title.dart';
import '../widgets/demo_mode_notice.dart';
import '../widgets/profile_menu_button.dart';
import '../widgets/theme_toggle_button.dart';
import '../utils/navigation_extensions.dart';

class JobsPage extends StatefulWidget {
  const JobsPage({
    super.key,
    this.initialJobId,
    this.initialLocationId,
    this.openedFromClient = false,
    this.openedFromEmployee = false,
  });

  final String? initialJobId;
  final int? initialLocationId;
  final bool openedFromClient;
  final bool openedFromEmployee;

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> with BaseApiPageMixin<JobsPage> {
  final _profileIdController = TextEditingController(text: '1');
  final _locationIdController = TextEditingController(text: '1');
  final _dateController = TextEditingController(
    text: DateTime.now().toIso8601String().split('T').first,
  );

  late BackendKind _selectedBackend;
  late final TextEditingController _hostController;

  List<Job> _jobs = const [];
  List<JobTask> _tasks = const [];
  List<JobAssignment> _assignments = const [];
  List<Employee> _employees = const [];
  String? _selectedJobId;
  String? _selectedEmployeeId;
  bool get _isAdmin => AuthSession.current?.user.isAdmin == true;
  bool get _isClient => AuthSession.current?.user.isClient == true;
  bool get _isEmployee => AuthSession.current?.user.isEmployee == true;

  @override
  void initState() {
    super.initState();
    _selectedBackend = backend.kind;
    _hostController = TextEditingController(text: BackendRuntime.host);
  }

  @override
  bool checkAuthorization() {
    final session = AuthSession.current;
    if (session == null) return false;
    if (!session.user.isAdmin &&
        !session.user.isClient &&
        !session.user.isEmployee) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin, employee, or client access required'),
        ),
      );
      context.navigateToHome();
      return false;
    }
    return true;
  }

  @override
  Future<void> loadData() async {
    await _loadJobs();
    if (AuthSession.current?.user.isAdmin == true) {
      await _loadEmployees();
    }
  }

  @override
  void dispose() {
    _profileIdController.dispose();
    _locationIdController.dispose();
    _dateController.dispose();
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
    context.navigateToHome();
  }

  Future<void> _loadEmployees() async {
    if (token == null || token!.isEmpty) return;
    try {
      final employees = await api.listEmployees(bearerToken: token!);
      if (!mounted) return;
      setState(() {
        _employees = employees;
        _selectedEmployeeId = employees.isNotEmpty ? employees.first.id : null;
      });
    } catch (_) {}
  }

  Future<void> _loadJobs() async {
    if (token == null || token!.isEmpty) return;
    final jobs = await api.listJobs(bearerToken: token!);
    final visibleJobs = _isClient && widget.initialLocationId != null
        ? jobs
              .where((job) => job.locationId == widget.initialLocationId)
              .toList()
        : jobs;
    final preferredJobId = widget.initialJobId;
    final selectedJobId = (preferredJobId != null &&
            visibleJobs.any((job) => job.id == preferredJobId))
        ? preferredJobId
        : (visibleJobs.isNotEmpty ? visibleJobs.first.id : null);
    if (!mounted) return;
    setState(() {
      _jobs = visibleJobs;
      _selectedJobId = selectedJobId;
    });
    await _loadSelectedJobDetails();
  }

  Future<void> _loadSelectedJobDetails() async {
    final jobId = _selectedJobId;
    if (token == null || token!.isEmpty || jobId == null || jobId.isEmpty) {
      return;
    }
    try {
      final tasks = await api.listJobTasks(jobId, bearerToken: token!);
      final assignments = await api.listJobAssignments(
        jobId,
        bearerToken: token!,
      );
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _assignments = assignments;
      });
    } catch (err) {
      if (!mounted) return;
      setError(userFacingError(err));
    }
  }

  Future<void> _createJob() async {
    if (AppEnv.isDemoMode) {
      setError('Demo mode: create/edit/delete actions are disabled');
      return;
    }
    if (token == null || token!.isEmpty) {
      setError('Login required');
      return;
    }
    try {
      await api.createJob(
        JobCreateInput(
          profileId: int.parse(_profileIdController.text.trim()),
          locationId: int.parse(_locationIdController.text.trim()),
          scheduledDate: _dateController.text.trim(),
        ),
        bearerToken: token!,
      );
      await loadData();
    } catch (err) {
      if (!mounted) return;
      setError(userFacingError(err));
    }
  }

  Future<void> _assignEmployee() async {
    if (AppEnv.isDemoMode) {
      setError('Demo mode: create/edit/delete actions are disabled');
      return;
    }
    final jobId = _selectedJobId;
    final employeeId = _selectedEmployeeId;
    if (token == null || token!.isEmpty || jobId == null || employeeId == null) {
      return;
    }
    try {
      await api.createJobAssignment(
        jobId,
        JobAssignmentCreateInput(employeeId: employeeId),
        bearerToken: token!,
      );
      await _loadSelectedJobDetails();
    } catch (err) {
      if (!mounted) return;
      setError(userFacingError(err));
    }
  }

  @override
  Widget buildContent(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
          if (_isAdmin && BackendRuntime.allowBackendOverride) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [BackendKind.rust]
                  .map(
                    (kind) => ChoiceChip(
                      label: Text(switch (kind) {
                        BackendKind.rust => 'Rust',
                        _ => 'Rust',
                      }),
                      selected: _selectedBackend == kind,
                      onSelected: (_) =>
                          setState(() => _selectedBackend = kind),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
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
                FilledButton(
                  onPressed: _applyBackendSelection,
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
          if (_isClient && widget.openedFromClient) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _selectedJobId == null
                      ? 'No matching jobs were found for this location yet.'
                      : 'Showing job details from the client dashboard.',
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_isEmployee && widget.openedFromEmployee) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _selectedJobId == null
                      ? 'No matching jobs were found for this selection.'
                      : 'Showing job details from the employee dashboard.',
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
          if (AppEnv.isDemoMode) ...[
            const DemoModeNotice(
              message:
                  'Demo mode: job creation and assignment actions are read-only in preview.',
            ),
            const SizedBox(height: 12),
          ],
          if (_isAdmin) ...[
            const Text(
              'Create Job (admin only)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _profileIdController,
                    decoration: const InputDecoration(
                      labelText: 'Profile ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _locationIdController,
                    decoration: const InputDecoration(
                      labelText: 'Location ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _dateController,
                    decoration: const InputDecoration(
                      labelText: 'YYYY-MM-DD',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: isLoading || AppEnv.isDemoMode ? null : _createJob,
                  child: const Text('Create'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedJobId,
            decoration: const InputDecoration(
              labelText: 'Selected Job',
              border: OutlineInputBorder(),
            ),
            items: _jobs
                .map(
                  (job) => DropdownMenuItem(
                    value: job.id,
                    child: Text('${job.jobNumber} • ${job.status}'),
                  ),
                )
                .toList(),
            onChanged: (value) async {
              if (value == null) return;
              setState(() => _selectedJobId = value);
              await _loadSelectedJobDetails();
            },
          ),
          const SizedBox(height: 12),
          if (_isAdmin)
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedEmployeeId,
                    decoration: const InputDecoration(
                      labelText: 'Assign Employee',
                      border: OutlineInputBorder(),
                    ),
                    items: _employees
                        .map(
                          (employee) => DropdownMenuItem(
                            value: employee.id,
                            child: Text('${employee.name} (${employee.id})'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedEmployeeId = value),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: isLoading || AppEnv.isDemoMode
                      ? null
                      : _assignEmployee,
                  child: const Text('Assign'),
                ),
              ],
            ),
          const SizedBox(height: 12),
          _ListPane(
            title: 'Assignments (${_assignments.length})',
            rows: _assignments
                .map((a) => '${a.id} • ${a.employeeId} • active=${a.isActive}')
                .toList(),
          ),
          const SizedBox(height: 12),
          _ListPane(
            title: 'Tasks (${_tasks.length})',
            rows: _tasks
                .map(
                  (task) =>
                      '${task.id} • ${task.name} • completed=${task.completed}',
                )
                .toList(),
          ),
        ],
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BrandAppBarTitle(),
        bottom: const BackendBanner(),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            onPressed: isLoading ? null : reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          const ProfileMenuButton(),
        ],
      ),
      body: buildBody(context),
    );
  }
}

class _ListPane extends StatelessWidget {
  const _ListPane({required this.title, required this.rows});

  final String title;
  final List<String> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (rows.isEmpty) const Text('No data'),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(row),
            ),
          ),
        ],
      ),
    );
  }
}
