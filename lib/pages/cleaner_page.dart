import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/backend_config.dart';
import '../models/task_definition.dart';
import '../models/task_rule.dart';
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
    text: 'admin@andersonexpress.com',
  );
  final _passwordController = TextEditingController(text: 'dev-password');
  final _tokenController = TextEditingController();
  late BackendKind _selectedBackend;
  late final TextEditingController _hostController;

  BackendConfig get _backend => BackendRuntime.config;
  ApiService get _api => ApiService();

  bool _loading = false;
  String? _error;
  List<TaskDefinition> _taskDefinitions = const [];
  List<TaskRule> _taskRules = const [];

  final _taskCodeController = TextEditingController();
  final _taskNameController = TextEditingController();
  final _taskCategoryController = TextEditingController(text: 'general');
  final _taskDescriptionController = TextEditingController();

  final _ruleTaskIdController = TextEditingController();
  final _ruleConditionController = TextEditingController(
    text: '{"location.type":"residential"}',
  );
  final _ruleDisplayOrderController = TextEditingController(text: '10');
  final _ruleNotesController = TextEditingController();

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
    _taskCodeController.dispose();
    _taskNameController.dispose();
    _taskCategoryController.dispose();
    _taskDescriptionController.dispose();
    _ruleTaskIdController.dispose();
    _ruleConditionController.dispose();
    _ruleDisplayOrderController.dispose();
    _ruleNotesController.dispose();
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
      _taskDefinitions = const [];
      _taskRules = const [];
      _tokenController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Backend set to ${next.label} (${next.baseUrl})')),
    );
  }

  Future<void> _fetchToken() async {
    try {
      final token = await _api.fetchToken(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      setState(() {
        _tokenController.text = token;
      });
      await _loadCleanerData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Token fetched')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _loadCleanerData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = _tokenController.text.trim();
      final taskDefinitions = await _api.listTaskDefinitions(
        bearerToken: token,
      );
      final taskRules = await _api.listTaskRules(bearerToken: token);
      if (!mounted) return;
      setState(() {
        _taskDefinitions = taskDefinitions;
        _taskRules = taskRules;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _createTaskDefinition() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() => _error = 'Fetch token first');
      return;
    }
    try {
      final created = await _api.createTaskDefinition(
        TaskDefinitionCreateInput(
          code: _taskCodeController.text.trim(),
          name: _taskNameController.text.trim(),
          category: _taskCategoryController.text.trim(),
          description: _taskDescriptionController.text.trim().isEmpty
              ? null
              : _taskDescriptionController.text.trim(),
        ),
        bearerToken: token,
      );
      if (!mounted) return;
      _taskCodeController.clear();
      _taskNameController.clear();
      _taskDescriptionController.clear();
      await _loadCleanerData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task definition created: ${created.code}')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  Future<void> _createTaskRule() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() => _error = 'Fetch token first');
      return;
    }
    try {
      final taskDefinitionId = int.parse(_ruleTaskIdController.text.trim());
      final decoded = jsonDecode(_ruleConditionController.text.trim());
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Conditions must be a JSON object');
      }
      final created = await _api.createTaskRule(
        TaskRuleCreateInput(
          taskDefinitionId: taskDefinitionId,
          appliesWhen: decoded,
          displayOrder: int.tryParse(_ruleDisplayOrderController.text.trim()),
          notesTemplate: _ruleNotesController.text.trim().isEmpty
              ? null
              : _ruleNotesController.text.trim(),
        ),
        bearerToken: token,
      );
      if (!mounted) return;
      _ruleNotesController.clear();
      await _loadCleanerData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task rule created: ${created.id}')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cleaner - Task Definitions & Rules'),
        bottom: const BackendBanner(),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadCleanerData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
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
                      onSelected: (_) =>
                          setState(() => _selectedBackend = kind),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
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
                labelText: 'Auth Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Auth Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Cleaning configuration endpoints are admin-only in all backends.',
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _fetchToken,
                icon: const Icon(Icons.key),
                label: const Text('Fetch Token'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tokenController,
              decoration: InputDecoration(
                labelText: 'Bearer Token',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: _loadCleanerData,
                  icon: const Icon(Icons.login),
                ),
              ),
            ),
            const SizedBox(height: 12),
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
                  : Column(
                      children: [
                        _CreateSection(
                          title: 'Create Task Definition',
                          children: [
                            TextField(
                              controller: _taskCodeController,
                              decoration: const InputDecoration(
                                labelText: 'Code (e.g. CLEAN_WINDOWS)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _taskNameController,
                              decoration: const InputDecoration(
                                labelText: 'Name',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _taskCategoryController,
                                    decoration: const InputDecoration(
                                      labelText: 'Category',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.icon(
                                  onPressed: _loading
                                      ? null
                                      : _createTaskDefinition,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Create'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _taskDescriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _CreateSection(
                          title: 'Create Task Rule',
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _ruleTaskIdController,
                                    decoration: const InputDecoration(
                                      labelText: 'Task Definition ID',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _ruleDisplayOrderController,
                                    decoration: const InputDecoration(
                                      labelText: 'Display Order',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.icon(
                                  onPressed: _loading ? null : _createTaskRule,
                                  icon: const Icon(Icons.rule),
                                  label: const Text('Create'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _ruleConditionController,
                              decoration: const InputDecoration(
                                labelText: 'Conditions JSON (flat key/value)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _ruleNotesController,
                              decoration: const InputDecoration(
                                labelText: 'Notes Template',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: _ListPane(
                                  title:
                                      'Task Definitions (${_taskDefinitions.length})',
                                  rows: _taskDefinitions
                                      .map(
                                        (item) =>
                                            '${item.id} • ${item.code} • ${item.category}',
                                      )
                                      .toList(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ListPane(
                                  title: 'Task Rules (${_taskRules.length})',
                                  rows: _taskRules
                                      .map(
                                        (item) =>
                                            '${item.id} • task ${item.taskDefinitionId} • required=${item.required}',
                                      )
                                      .toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateSection extends StatelessWidget {
  const _CreateSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
          ...children,
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
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: rows.isEmpty
                ? const Center(child: Text('No data'))
                : ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (_, index) =>
                        ListTile(dense: true, title: Text(rows[index])),
                  ),
          ),
        ],
      ),
    );
  }
}
