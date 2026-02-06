import 'package:flutter/material.dart';
import '../services/api_service.dart';

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

  @override
  void initState() {
    super.initState();
    _checkServices();
  }

  Future<void> _checkServices() async {
    final results = await Future.wait([
      _api.checkHealth(ApiService.rustBase),
      _api.checkHealth(ApiService.pythonBase),
      _api.checkHealth(ApiService.vaporBase),
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
      appBar: AppBar(title: const Text('System Status'), elevation: 0),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF5F7FA), Color(0xFFE4E8ED)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
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
                        child: Padding(
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

                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/cleaner');
                                    },
                                    icon: const Icon(Icons.cleaning_services),
                                    label: const Text('Cleaner'),
                                  ),
                                  const SizedBox(width: 16),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/admin');
                                    },
                                    icon: const Icon(
                                      Icons.admin_panel_settings,
                                    ),
                                    label: const Text('Admin'),
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
    );
  }
}
