import 'package:flutter/material.dart';

import '../models/job.dart';
import '../models/location.dart';
import '../services/api_service.dart';
import '../services/auth_session.dart';
import '../widgets/backend_banner.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool loading = true;
  String? error;
  List<Job> _adminPendingJobs = const [];
  List<Job> _cleanerJobs = const [];
  List<Location> _clientLocations = const [];
  List<Job> _clientPendingJobs = const [];

  AuthSessionState? get _session => AuthSession.current;
  bool get _isAdmin => _session?.user.isAdmin == true;
  bool get _isEmployee => _session?.user.isEmployee == true;
  bool get _isClient => _session?.user.isClient == true;

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
    _bootstrap();
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
      AuthSession.set(
        AuthSessionState(
          token: session.token,
          user: user,
          loginEmail: session.loginEmail,
          loginPassword: session.loginPassword,
        ),
      );
      return true;
    } catch (_) {
      final email = session.loginEmail;
      final password = session.loginPassword;
      if (email == null || password == null) {
        AuthSession.clear();
        return false;
      }
      try {
        final api = ApiService();
        final token = await api.fetchToken(email: email, password: password);
        final user = await api.whoAmI(bearerToken: token);
        AuthSession.set(
          AuthSessionState(
            token: token,
            user: user,
            loginEmail: email,
            loginPassword: password,
          ),
        );
        return true;
      } catch (_) {
        AuthSession.clear();
        return false;
      }
    }
  }

  Future<void> _loadDashboard() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final api = ApiService();
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
        _adminPendingJobs = adminPending;
        _cleanerJobs = cleanerJobs;
        _clientLocations = clientLocations;
        _clientPendingJobs = clientPending;
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
            tooltip: 'Refresh',
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
