import 'package:flutter/material.dart';

import '../models/backend_config.dart';
import '../models/employee.dart';
import '../services/api_service.dart';

class QaSmokePage extends StatefulWidget {
  const QaSmokePage({super.key});

  @override
  State<QaSmokePage> createState() => _QaSmokePageState();
}

class _QaSmokePageState extends State<QaSmokePage> {
  BackendKind _backendKind = BackendConfig.fromEnvironment().kind;
  final _baseUrlController = TextEditingController();
  final _emailController = TextEditingController(
    text: 'admin@andersonexpress.com',
  );
  final _passwordController = TextEditingController(text: 'admin123');

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
    return switch (kind) {
      BackendKind.rust => ApiService.rustConfig,
      BackendKind.python => ApiService.pythonConfig,
      BackendKind.vapor => ApiService.vaporConfig,
    };
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

  Future<void> _runEmployeeSmoke() async {
    setState(() {
      _running = true;
      _logs.clear();
    });

    final service = ApiService(backend: _activeConfig());
    try {
      await _fetchToken();
      final token = _token;
      if (token == null || token.isEmpty) {
        throw Exception('Token missing');
      }

      final suffix = DateTime.now().millisecondsSinceEpoch;
      final created = await service.createEmployee(
        EmployeeCreateInput(
          name: 'QA Smoke $suffix',
          email: 'qa.smoke.$suffix@example.com',
          accessLevel: 'USER',
          city: 'QA',
          state: 'SM',
        ),
        bearerToken: token,
      );
      _log('Create: ${created.id}');

      final listed = await service.listEmployees(bearerToken: token);
      final found = listed.any((e) => e.id == created.id);
      _log('List: ${found ? "found created employee" : "not found"}');
      if (!found) {
        throw Exception('Created employee missing from list');
      }

      final updated = await service.updateEmployee(
        created.id,
        const EmployeeUpdateInput(city: 'QA-UPDATED'),
        bearerToken: token,
      );
      _log('Update: city=${updated.city ?? ""}');

      final deleted = await service.deleteEmployee(
        created.id,
        bearerToken: token,
      );
      _log('Delete: $deleted');
      _log('Smoke test passed');
    } catch (error) {
      _log('Smoke test failed: $error');
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
      appBar: AppBar(title: const Text('QA Smoke - Employee CRUD')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<BackendKind>(
              initialValue: _backendKind,
              decoration: const InputDecoration(
                labelText: 'Backend',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: BackendKind.rust, child: Text('Rust')),
                DropdownMenuItem(
                  value: BackendKind.python,
                  child: Text('Python'),
                ),
                DropdownMenuItem(
                  value: BackendKind.vapor,
                  child: Text('Vapor'),
                ),
              ],
              onChanged: _running
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _backendKind = value;
                        _baseUrlController.text = _defaultConfig(value).baseUrl;
                      });
                    },
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
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _running ? null : _fetchToken,
                  icon: const Icon(Icons.key),
                  label: const Text('Fetch Token'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _running ? null : _runEmployeeSmoke,
                  icon: _running
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: const Text('Run Employee Smoke'),
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
