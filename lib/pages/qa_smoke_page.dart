import 'package:flutter/material.dart';

import '../models/backend_config.dart';
import '../models/client.dart';
import '../models/employee.dart';
import '../models/location.dart';
import '../models/task_definition.dart';
import '../models/task_rule.dart';
import '../services/api_service.dart';
import '../services/auth_session.dart';
import '../widgets/backend_banner.dart';
import '../widgets/brand_app_bar_title.dart';

class QaSmokePage extends StatefulWidget {
  const QaSmokePage({super.key});

  @override
  State<QaSmokePage> createState() => _QaSmokePageState();
}

class _QaSmokePageState extends State<QaSmokePage> {
  final BackendKind _backendKind = BackendKind.rust;
  final _baseUrlController = TextEditingController();
  final _emailController = TextEditingController(
    text: 'admin@andersonexpress.com',
  );
  final _passwordController = TextEditingController(text: 'dev-password');

  bool _running = false;
  String? _token;
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _baseUrlController.text = _defaultConfig(_backendKind).baseUrl;
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  BackendConfig _defaultConfig(BackendKind kind) {
    return ApiService.rustConfig;
  }

  BackendConfig _activeConfig() {
    final defaults = _defaultConfig(_backendKind);
    final override = _baseUrlController.text.trim();
    return BackendConfig(
      kind: _backendKind,
      baseUrl: override.isNotEmpty ? override : defaults.baseUrl,
      healthPath: defaults.healthPath,
      employeesPath: defaults.employeesPath,
    );
  }

  void _log(String message) {
    setState(() {
      _logs.add(message);
    });
  }

  Future<void> _fetchToken() async {
    final service = ApiService(backend: _activeConfig());
    _log('Fetching token...');
    final token = await service.fetchToken(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    setState(() {
      _token = token;
    });
    _log('Token fetched');
  }

  Future<String> _ensureToken(ApiService service) async {
    if (_token == null || _token!.isEmpty) {
      await _fetchToken();
    }
    final token = _token;
    if (token == null || token.isEmpty) {
      throw Exception('Token missing');
    }
    return token;
  }

  Future<void> _runEmployeeSmoke() async {
    setState(() {
      _running = true;
      _logs.clear();
    });

    final service = ApiService(backend: _activeConfig());
    try {
      final token = await _ensureToken(service);
      final suffix = DateTime.now().millisecondsSinceEpoch;

      final created = await service.createEmployee(
        EmployeeCreateInput(
          name: 'QA Smoke Employee $suffix',
          email: 'qa.smoke.employee.$suffix@example.com',
          accessLevel: 'USER',
          city: 'QA',
          state: 'SM',
        ),
        bearerToken: token,
      );
      _log('Employee create: ${created.id}');

      final listed = await service.listEmployees(bearerToken: token);
      final found = listed.any((e) => e.id == created.id);
      _log('Employee list: ${found ? "found created employee" : "not found"}');
      if (!found) {
        throw Exception('Created employee missing from list');
      }

      final updated = await service.updateEmployee(
        created.id,
        const EmployeeUpdateInput(city: 'QA-UPDATED'),
        bearerToken: token,
      );
      _log('Employee update: city=${updated.city ?? ""}');

      final deleted = await service.deleteEmployee(
        created.id,
        bearerToken: token,
      );
      _log('Employee delete: $deleted');
      _log('Employee smoke passed');
    } catch (error) {
      _log('Employee smoke failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
        });
      }
    }
  }

  Future<void> _runClientSmoke() async {
    setState(() {
      _running = true;
      _logs.clear();
    });

    final service = ApiService(backend: _activeConfig());
    try {
      final token = await _ensureToken(service);
      final suffix = DateTime.now().millisecondsSinceEpoch;

      final created = await service.createClient(
        ClientCreateInput(
          name: 'QA Smoke Client $suffix',
          email: 'qa.smoke.client.$suffix@example.com',
          city: 'QA',
          state: 'SM',
        ),
        bearerToken: token,
      );
      _log('Client create: ${created.id}');

      final listed = await service.listClients(bearerToken: token);
      final found = listed.any((c) => c.id == created.id);
      _log('Client list: ${found ? "found created client" : "not found"}');
      if (!found) {
        throw Exception('Created client missing from list');
      }

      final updated = await service.updateClient(
        created.id,
        const ClientUpdateInput(city: 'QA-UPDATED'),
        bearerToken: token,
      );
      _log('Client update: city=${updated.city ?? ""}');

      final deleted = await service.deleteClient(
        created.id,
        bearerToken: token,
      );
      _log('Client delete: $deleted');
      _log('Client smoke passed');
    } catch (error) {
      _log('Client smoke failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
        });
      }
    }
  }

  Future<void> _runLocationSmoke() async {
    setState(() {
      _running = true;
      _logs.clear();
    });

    final service = ApiService(backend: _activeConfig());
    try {
      final token = await _ensureToken(service);
      final suffix = DateTime.now().millisecondsSinceEpoch;

      final client = await service.createClient(
        ClientCreateInput(
          name: 'QA Smoke Location Client $suffix',
          email: 'qa.smoke.location.client.$suffix@example.com',
          city: 'QA',
          state: 'SM',
        ),
        bearerToken: token,
      );
      _log('Location smoke client create: ${client.id}');

      final clientId = int.tryParse(client.id);
      if (clientId == null) {
        throw Exception('Invalid client id: ${client.id}');
      }

      final created = await service.createLocation(
        LocationCreateInput(
          type: 'residential',
          clientId: clientId,
          city: 'QA',
          state: 'SM',
          address: 'QA Street $suffix',
          zipCode: '00000',
        ),
        bearerToken: token,
      );
      _log('Location create: ${created.id}');

      final listed = await service.listLocations(
        clientId: clientId,
        bearerToken: token,
      );
      final found = listed.any((l) => l.id == created.id);
      _log('Location list: ${found ? "found created location" : "not found"}');
      if (!found) {
        throw Exception('Created location missing from list');
      }

      final updated = await service.updateLocation(
        created.id,
        const LocationUpdateInput(city: 'QA-UPDATED'),
        bearerToken: token,
      );
      _log('Location update: city=${updated.city ?? ""}');

      final deletedLocation = await service.deleteLocation(
        created.id,
        bearerToken: token,
      );
      _log('Location delete: $deletedLocation');

      final deletedClient = await service.deleteClient(
        client.id,
        bearerToken: token,
      );
      _log('Location smoke cleanup client delete: $deletedClient');
      _log('Location smoke passed');
    } catch (error) {
      _log('Location smoke failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
        });
      }
    }
  }

  Future<void> _runCleaningSmoke() async {
    setState(() {
      _running = true;
      _logs.clear();
    });

    final service = ApiService(backend: _activeConfig());
    try {
      final token = await _ensureToken(service);
      final suffix = DateTime.now().millisecondsSinceEpoch;

      final task = await service.createTaskDefinition(
        TaskDefinitionCreateInput(
          code: 'QA_SMOKE_TASK_$suffix',
          name: 'QA Smoke Task $suffix',
          category: 'qa',
          description: 'Created by QA cleaner smoke',
        ),
        bearerToken: token,
      );
      _log('Cleaning task definition create: ${task.id}');

      final listedTasks = await service.listTaskDefinitions(bearerToken: token);
      final taskFound = listedTasks.any((t) => t.id == task.id);
      _log(
        'Cleaning task definition list: ${taskFound ? "found created task definition" : "not found"}',
      );
      if (!taskFound) {
        throw Exception('Created task definition missing from list');
      }

      final taskId = int.tryParse(task.id);
      if (taskId == null) {
        throw Exception('Invalid task definition id: ${task.id}');
      }

      final rule = await service.createTaskRule(
        TaskRuleCreateInput(
          taskDefinitionId: taskId,
          appliesWhen: {'location.type': 'residential'},
          required: true,
          displayOrder: 10,
          notesTemplate: 'QA cleaner smoke note',
        ),
        bearerToken: token,
      );
      _log('Cleaning task rule create: ${rule.id}');

      final listedRules = await service.listTaskRules(bearerToken: token);
      final ruleFound = listedRules.any((r) => r.id == rule.id);
      _log(
        'Cleaning task rule list: ${ruleFound ? "found created rule" : "not found"}',
      );
      if (!ruleFound) {
        throw Exception('Created task rule missing from list');
      }

      _log('Cleaning smoke passed');
    } catch (error) {
      _log('Cleaning smoke failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BrandAppBarTitle(),
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
            onPressed: _running
                ? null
                : () {
                    setState(() {
                      _logs.clear();
                    });
                  },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              initialValue: 'Rust',
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Backend',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _baseUrlController,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: _running ? null : _fetchToken,
                  icon: const Icon(Icons.key),
                  label: const Text('Fetch Token'),
                ),
                FilledButton.icon(
                  onPressed: _running ? null : _runEmployeeSmoke,
                  icon: _running
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.badge),
                  label: const Text('Run Employee Smoke'),
                ),
                FilledButton.icon(
                  onPressed: _running ? null : _runClientSmoke,
                  icon: _running
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.business),
                  label: const Text('Run Client Smoke'),
                ),
                FilledButton.icon(
                  onPressed: _running ? null : _runLocationSmoke,
                  icon: _running
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.location_on),
                  label: const Text('Run Location Smoke'),
                ),
                FilledButton.icon(
                  onPressed: _running ? null : _runCleaningSmoke,
                  icon: _running
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cleaning_services),
                  label: const Text('Run Cleaner Smoke'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _logs.isEmpty
                    ? const Text('No run yet')
                    : ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (context, index) =>
                            Text('• ${_logs[index]}'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
