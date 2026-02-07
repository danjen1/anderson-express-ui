import 'package:flutter/material.dart';

import '../models/backend_config.dart';
import '../services/api_service.dart';
import '../services/auth_session.dart';
import '../services/backend_runtime.dart';
import '../widgets/backend_banner.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool rustOk = false;
  bool pythonOk = false;
  bool vaporOk = false;
  bool loading = true;
  bool visible = false;

  DateTime? lastChecked;

  final ApiService _api = ApiService();
  late BackendKind _selectedBackend;
  late final TextEditingController _hostController;

  BackendConfig get _activeBackend => BackendRuntime.config;
  AuthSessionState? get _session => AuthSession.current;
  bool get _isAdmin => _session?.user.isAdmin == true;
  bool get _isEmployee => _session?.user.isEmployee == true;
  bool get _isClient => _session?.user.isClient == true;

  BackendConfig _healthConfigFor(BackendKind kind) {
    final uri = Uri.parse(_activeBackend.baseUrl);
    final host = uri.host.isNotEmpty ? uri.host : 'localhost';
    final scheme = uri.scheme.isNotEmpty ? uri.scheme : 'http';
    final port = switch (kind) {
      BackendKind.rust => 9000,
      BackendKind.python => 8000,
      BackendKind.vapor => 9001,
    };
    return BackendConfig(
      kind: kind,
      baseUrl: '$scheme://$host:$port',
      healthPath: '/healthz',
      employeesPath: '/api/v1/employees',
    );
  }

  @override
  void initState() {
    super.initState();
    if (_session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/');
      });
      return;
    }
    _selectedBackend = _activeBackend.kind;
    _hostController = TextEditingController(text: BackendRuntime.host);
    _checkServices();
  }

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  Future<void> _checkServices() async {
    setState(() {
      loading = true;
    });
    final results = await Future.wait([
      _api.checkHealth(_healthConfigFor(BackendKind.rust)),
      _api.checkHealth(_healthConfigFor(BackendKind.python)),
      _api.checkHealth(_healthConfigFor(BackendKind.vapor)),
    ]);

    if (!mounted) return;

    setState(() {
      rustOk = results[0];
      pythonOk = results[1];
      vaporOk = results[2];
      loading = false;
      lastChecked = DateTime.now();
    });

    // Trigger entrance animation
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      setState(() => visible = true);
    }
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
    setState(() {});
    await _checkServices();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Active backend set to ${next.label} (${next.baseUrl})'),
      ),
    );
  }

  String _timeAgo(DateTime time) {
    final seconds = DateTime.now().difference(time).inSeconds;
    if (seconds < 5) return 'just now';
    if (seconds < 60) return '$seconds seconds ago';
    return '${seconds ~/ 60} minutes ago';
  }

  Widget _statusCard(String name, bool ok) {
    final color = ok ? Colors.green : Colors.red;
    final icon = ok ? Icons.check_circle : Icons.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            ok ? 'Online' : 'Offline',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Status'),
        elevation: 0,
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
            onPressed: _checkServices,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh health checks',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF5F7FA), Color(0xFFE4E8ED)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: loading
                  ? const CircularProgressIndicator()
                  : AnimatedOpacity(
                      opacity: visible ? 1 : 0,
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      child: AnimatedScale(
                        scale: visible ? 1 : 0.96,
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOut,
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Animated logo placeholder
                                AnimatedScale(
                                  scale: visible ? 1 : 0.85,
                                  duration: const Duration(seconds: 1),
                                  curve: Curves.easeOutBack,
                                  child: Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.local_shipping,
                                      size: 40,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 20),

                                const Text(
                                  'Services Online',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Live system health overview',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.blue.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ACTIVE BACKEND',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.blue.shade900,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _activeBackend.label,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _activeBackend.baseUrl,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.blue.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
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
                                          onSelected: (_) {
                                            setState(
                                              () => _selectedBackend = kind,
                                            );
                                          },
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
                                          labelText:
                                              'Backend Host (e.g. archlinux)',
                                          border: OutlineInputBorder(),
                                          isDense: true,
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
                                if (lastChecked != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Last checked: ${_timeAgo(lastChecked!)}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 32),

                                _statusCard('Rust API', rustOk),
                                const SizedBox(height: 12),
                                _statusCard('Python API', pythonOk),
                                const SizedBox(height: 12),
                                _statusCard('Vapor API', vaporOk),

                                const SizedBox(height: 32),
                                const Divider(),
                                const SizedBox(height: 20),

                                const Text(
                                  'Enter Demo As',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    if (_isEmployee)
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.pushNamed(
                                            context,
                                            '/cleaner',
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.cleaning_services,
                                        ),
                                        label: const Text('Cleaner'),
                                      ),
                                    if (_isAdmin) ...[
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.pushNamed(
                                            context,
                                            '/admin',
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.admin_panel_settings,
                                        ),
                                        label: const Text('Employees'),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.pushNamed(
                                            context,
                                            '/clients',
                                          );
                                        },
                                        icon: const Icon(Icons.business),
                                        label: const Text('Clients'),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.pushNamed(context, '/jobs');
                                        },
                                        icon: const Icon(Icons.work),
                                        label: const Text('Jobs'),
                                      ),
                                    ],
                                    if (_isAdmin || _isClient)
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.pushNamed(
                                            context,
                                            '/locations',
                                          );
                                        },
                                        icon: const Icon(Icons.location_on),
                                        label: const Text('Locations'),
                                      ),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.pushNamed(
                                          context,
                                          '/qa-smoke',
                                        );
                                      },
                                      icon: const Icon(Icons.science),
                                      label: const Text('QA Smoke'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
