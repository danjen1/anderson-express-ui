import 'package:flutter/material.dart';

import '../models/backend_config.dart';
import '../models/job.dart';
import '../models/location.dart';
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
  String? error;
  DateTime? lastChecked;

  late BackendKind _selectedBackend;
  late final TextEditingController _hostController;
  List<Job> _adminPendingJobs = const [];
  List<Job> _cleanerJobs = const [];
  List<Location> _clientLocations = const [];
  List<Job> _clientPendingJobs = const [];

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
    _selectedBackend = _activeBackend.kind;
    _hostController = TextEditingController(text: BackendRuntime.host);
    if (_session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/');
      });
      return;
    }
    _bootstrap();
  }

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final valid = await _ensureSessionIsValid();
    if (!mounted) return;
    if (!valid) {
      Navigator.pushReplacementNamed(context, '/');
      return;
    }
    await _loadDashboard();
  }

  Future<bool> _ensureSessionIsValid() async {
    final session = _session;
    if (session == null) {
      return false;
    }
    try {
      final user = await ApiService().whoAmI(bearerToken: session.token);
      AuthSession.set(AuthSessionState(token: session.token, user: user));
      return true;
    } catch (_) {
      AuthSession.clear();
      return false;
    }
  }

  Future<void> _loadDashboard() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final api = ApiService();
      final results = await Future.wait([
        api.checkHealth(_healthConfigFor(BackendKind.rust)),
        api.checkHealth(_healthConfigFor(BackendKind.python)),
        api.checkHealth(_healthConfigFor(BackendKind.vapor)),
      ]);

      final token = _session?.token ?? '';
      List<Job> adminPending = const [];
      List<Job> cleanerJobs = const [];
      List<Location> clientLocations = const [];
      List<Job> clientPending = const [];

      if (_isAdmin) {
        adminPending = await api.listJobs(
          statusFilter: const ['pending'],
          bearerToken: token,
        );
      } else if (_isEmployee) {
        cleanerJobs = await api.listJobs(bearerToken: token);
      } else if (_isClient) {
        clientLocations = await api.listLocations(bearerToken: token);
        clientPending = await api.listJobs(
          statusFilter: const ['pending'],
          bearerToken: token,
        );
      }

      if (!mounted) return;
      setState(() {
        rustOk = results[0];
        pythonOk = results[1];
        vaporOk = results[2];
        _adminPendingJobs = adminPending;
        _cleanerJobs = cleanerJobs;
        _clientLocations = clientLocations;
        _clientPendingJobs = clientPending;
        lastChecked = DateTime.now();
      });
    } catch (loadError) {
      if (!mounted) return;
      setState(() {
        error = loadError.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
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
    final stillValid = await _ensureSessionIsValid();
    if (!mounted) return;
    if (!stillValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Session is not valid on selected backend. Please sign in again.',
          ),
        ),
      );
      Navigator.pushReplacementNamed(context, '/');
      return;
    }
    await _loadDashboard();
  }

  String _timeAgo(DateTime time) {
    final seconds = DateTime.now().difference(time).inSeconds;
    if (seconds < 5) return 'just now';
    if (seconds < 60) return '$seconds seconds ago';
    return '${seconds ~/ 60} minutes ago';
  }

  Widget _statusChip(String name, bool ok) {
    final color = ok ? Colors.green : Colors.red;
    return Chip(
      avatar: Icon(
        ok ? Icons.check_circle : Icons.error,
        size: 18,
        color: color,
      ),
      label: Text('$name: ${ok ? 'Online' : 'Offline'}'),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
    );
  }

  Widget _cardList({
    required String title,
    required String empty,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            if (children.isEmpty)
              Text(empty, style: const TextStyle(color: Colors.black54)),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildAdminLanding() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/admin'),
              icon: const Icon(Icons.badge),
              label: const Text('Employees'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/clients'),
              icon: const Icon(Icons.business),
              label: const Text('Clients'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/locations'),
              icon: const Icon(Icons.location_on),
              label: const Text('Locations'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/jobs'),
              icon: const Icon(Icons.work),
              label: const Text('Jobs'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _cardList(
          title: 'Pending Jobs Overview',
          empty: 'No pending jobs',
          children: _adminPendingJobs
              .map(
                (job) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.schedule),
                  title: Text(job.jobNumber),
                  subtitle: Text(
                    'Location #${job.locationId} • ${job.scheduledDate}',
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildCleanerLanding() {
    return _cardList(
      title: 'Your Assigned Jobs',
      empty: 'No jobs assigned',
      children: _cleanerJobs
          .map(
            (job) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(job.jobNumber),
              subtitle: Text('${job.status} • ${job.scheduledDate}'),
              trailing: IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => Navigator.pushNamed(context, '/cleaner'),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildClientLanding() {
    return Column(
      children: [
        _cardList(
          title: 'Your Locations',
          empty: 'No locations found',
          children: _clientLocations
              .map(
                (location) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(location.locationNumber),
                  subtitle: Text(
                    '${location.type} • ${location.address ?? 'No address'}',
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        _cardList(
          title: 'Pending Jobs For Your Locations',
          empty: 'No pending jobs',
          children: _clientPendingJobs
              .map(
                (job) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.pending_actions),
                  title: Text(job.jobNumber),
                  subtitle: Text(
                    'Location #${job.locationId} • ${job.scheduledDate}',
                  ),
                ),
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
        title: const Text('Anderson Express'),
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
            onPressed: _loadDashboard,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh health checks',
          ),
        ],
      ),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadDashboard,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Service Status',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _statusChip('Rust', rustOk),
                                _statusChip('Python', pythonOk),
                                _statusChip('Vapor', vaporOk),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Switch API Backend',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
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
                                      onSelected: (_) => setState(
                                        () => _selectedBackend = kind,
                                      ),
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
                              const SizedBox(height: 8),
                              Text(
                                'Last checked: ${_timeAgo(lastChecked!)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (error != null)
                      Card(
                        color: Colors.red.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            error!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ),
                    if (_isAdmin) _buildAdminLanding(),
                    if (_isEmployee) _buildCleanerLanding(),
                    if (_isClient) _buildClientLanding(),
                  ],
                ),
              ),
      ),
    );
  }
}
