import 'package:flutter/material.dart';

import '../models/backend_config.dart';
import '../models/employee.dart';
import '../models/job.dart';
import '../models/job_assignment.dart';
import '../models/job_task.dart';
import '../services/api_service.dart';
import '../services/app_env.dart';
import '../services/auth_session.dart';
import '../services/backend_runtime.dart';
import '../utils/error_text.dart';
import '../widgets/backend_banner.dart';
import '../widgets/demo_mode_notice.dart';
import '../widgets/profile_menu_button.dart';
import '../widgets/theme_toggle_button.dart';

class JobsPage extends StatefulWidget {
  const JobsPage({super.key});

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  final _profileIdController = TextEditingController(text: '1');
  final _locationIdController = TextEditingController(text: '1');
  final _dateController = TextEditingController(
    text: DateTime.now().toIso8601String().split('T').first,
  );

  late BackendKind _selectedBackend;
  late final TextEditingController _hostController;

  bool _loading = false;
  String? _error;
  List<Job> _jobs = const [];
  List<JobTask> _tasks = const [];
  List<JobAssignment> _assignments = const [];
  List<Employee> _employees = const [];
  String? _selectedJobId;
  String? _selectedEmployeeId;
  String? get _token => AuthSession.current?.token.trim();

  ApiService get _api => ApiService();
  BackendConfig get _backend => BackendRuntime.config;

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
      await _loadJobs();
      await _loadEmployees();
    });
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
    Navigator.pushReplacementNamed(context, '/home');
  }

  Future<void> _loadEmployees() async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      final employees = await _api.listEmployees(bearerToken: token);
      if (!mounted) return;
      setState(() {
        _employees = employees;
        _selectedEmployeeId = employees.isNotEmpty ? employees.first.id : null;
      });
    } catch (_) {}
  }

  Future<void> _loadJobs() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() => _error = 'Login required');
      return;
    }
    setState(() => _loading = true);
    try {
      final jobs = await _api.listJobs(bearerToken: token);
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        if (_selectedJobId == null && jobs.isNotEmpty) {
          _selectedJobId = jobs.first.id;
        }
      });
      await _loadSelectedJobDetails();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadSelectedJobDetails() async {
    final token = _token;
    final jobId = _selectedJobId;
    if (token == null || token.isEmpty || jobId == null || jobId.isEmpty) {
      return;
    }
    try {
      final tasks = await _api.listJobTasks(jobId, bearerToken: token);
      final assignments = await _api.listJobAssignments(
        jobId,
        bearerToken: token,
      );
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _assignments = assignments;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = userFacingError(error));
    }
  }

  Future<void> _createJob() async {
    if (AppEnv.isDemoMode) {
      setState(
        () => _error = 'Demo mode: create/edit/delete actions are disabled',
      );
      return;
    }
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() => _error = 'Login required');
      return;
    }
    try {
      await _api.createJob(
        JobCreateInput(
          profileId: int.parse(_profileIdController.text.trim()),
          locationId: int.parse(_locationIdController.text.trim()),
          scheduledDate: _dateController.text.trim(),
        ),
        bearerToken: token,
      );
      await _loadJobs();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = userFacingError(error));
    }
  }

  Future<void> _assignEmployee() async {
    if (AppEnv.isDemoMode) {
      setState(
        () => _error = 'Demo mode: create/edit/delete actions are disabled',
      );
      return;
    }
    final token = _token;
    final jobId = _selectedJobId;
    final employeeId = _selectedEmployeeId;
    if (token == null || token.isEmpty || jobId == null || employeeId == null) {
      return;
    }
    try {
      await _api.createJobAssignment(
        jobId,
        JobAssignmentCreateInput(employeeId: employeeId),
        bearerToken: token,
      );
      await _loadSelectedJobDetails();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = userFacingError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anderson Express Cleaning Service'),
        bottom: const BackendBanner(),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            onPressed: _loading ? null : _loadJobs,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          const ProfileMenuButton(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (BackendRuntime.allowBackendOverride) ...[
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
          const SizedBox(height: 12),
          if (AppEnv.isDemoMode) ...[
            const DemoModeNotice(
              message:
                  'Demo mode: job creation and assignment actions are read-only in preview.',
            ),
            const SizedBox(height: 12),
          ],
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
                onPressed: _loading || AppEnv.isDemoMode ? null : _createJob,
                child: const Text('Create'),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Colors.red.shade700)),
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
                onPressed: _loading || AppEnv.isDemoMode
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
      ),
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
