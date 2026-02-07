import 'package:flutter/material.dart';

import '../models/backend_config.dart';
import '../models/job.dart';
import '../models/job_task.dart';
import '../services/api_service.dart';
import '../services/backend_runtime.dart';
import '../widgets/backend_banner.dart';

class CleanerPage extends StatefulWidget {
  const CleanerPage({super.key});

  @override
  State<CleanerPage> createState() => _CleanerPageState();
}

class _CleanerPageState extends State<CleanerPage> {
  final _emailController = TextEditingController(
    text: 'john@andersonexpress.com',
  );
  final _passwordController = TextEditingController(text: 'worker123');
  final _tokenController = TextEditingController();
  late BackendKind _selectedBackend;
  late final TextEditingController _hostController;

  BackendConfig get _backend => BackendRuntime.config;
  ApiService get _api => ApiService();

  bool _loading = false;
  String? _error;
  List<Job> _jobs = const [];
  List<JobTask> _tasks = const [];
  String? _selectedJobId;

  @override
  void initState() {
    super.initState();
    _selectedBackend = _backend.kind;
    _hostController = TextEditingController(text: BackendRuntime.host);
  }

  @override
  void dispose() {
    _hostController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _applyBackendSelection() async {
    final host = _hostController.text.trim().isEmpty
        ? BackendRuntime.host
        : _hostController.text.trim();
    final next = BackendConfig.forKind(
      _selectedBackend,
      host: host,
      scheme: BackendRuntime.scheme,
    );
    BackendRuntime.setConfig(next);
    if (!mounted) return;
    setState(() {
      _error = null;
      _jobs = const [];
      _tasks = const [];
      _selectedJobId = null;
      _tokenController.clear();
    });
  }

  Future<void> _fetchToken() async {
    try {
      final token = await _api.fetchToken(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      setState(() => _tokenController.text = token);
      await _loadAssignedJobs();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  Future<void> _loadAssignedJobs() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = _tokenController.text.trim();
      final jobs = await _api.listJobs(bearerToken: token);
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        if (_selectedJobId == null && jobs.isNotEmpty) {
          _selectedJobId = jobs.first.id;
        }
      });
      await _loadSelectedJobTasks();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadSelectedJobTasks() async {
    final token = _tokenController.text.trim();
    final jobId = _selectedJobId;
    if (token.isEmpty || jobId == null || jobId.isEmpty) return;
    try {
      final tasks = await _api.listJobTasks(jobId, bearerToken: token);
      if (!mounted) return;
      setState(() => _tasks = tasks);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  Future<void> _toggleTaskComplete(JobTask task, bool nextValue) async {
    final token = _tokenController.text.trim();
    final jobId = _selectedJobId;
    if (token.isEmpty || jobId == null) return;
    try {
      await _api.updateJobTask(
        jobId,
        task.id,
        JobTaskUpdateInput(completed: nextValue),
        bearerToken: token,
      );
      await _loadSelectedJobTasks();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cleaner - Assigned Jobs'),
        bottom: const BackendBanner(),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadAssignedJobs,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Cleaner users only see jobs assigned to them, including each job\'s task list.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Backend: ${_backend.label} (${_backend.baseUrl})',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: BackendKind.values
                .map(
                  (kind) => ChoiceChip(
                    label: Text(switch (kind) {
                      BackendKind.rust => 'Rust',
                      BackendKind.python => 'Python',
                      BackendKind.vapor => 'Vapor',
                    }),
                    selected: _selectedBackend == kind,
                    onSelected: (_) => setState(() => _selectedBackend = kind),
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
              FilledButton.icon(
                onPressed: _applyBackendSelection,
                icon: const Icon(Icons.check),
                label: const Text('Apply'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Cleaner Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Cleaner Password',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _loading ? null : _fetchToken,
              icon: const Icon(Icons.key),
              label: const Text('Fetch Token'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _tokenController,
            decoration: InputDecoration(
              labelText: 'Bearer Token',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: _loadAssignedJobs,
                icon: const Icon(Icons.login),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedJobId,
            decoration: const InputDecoration(
              labelText: 'Assigned Job',
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
              await _loadSelectedJobTasks();
            },
          ),
          const SizedBox(height: 12),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _tasks.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('No tasks for selected job'),
                        )
                      : Column(
                          children: _tasks
                              .map(
                                (task) => CheckboxListTile(
                                  value: task.completed,
                                  onChanged: (nextValue) {
                                    if (nextValue == null) return;
                                    _toggleTaskComplete(task, nextValue);
                                  },
                                  title: Text(task.name),
                                  subtitle: Text(
                                    '${task.category} • required=${task.required}',
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
        ],
      ),
    );
  }
}
