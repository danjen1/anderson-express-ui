import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_session.dart';
import '../services/backend_runtime.dart';

class BackendBanner extends StatefulWidget implements PreferredSizeWidget {
  const BackendBanner({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  State<BackendBanner> createState() => _BackendBannerState();
}

class _BackendBannerState extends State<BackendBanner> {
  final ApiService _api = ApiService();
  Timer? _healthTimer;
  bool _rustOnline = false;

  @override
  void initState() {
    super.initState();
    _refreshHealth();
    _healthTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refreshHealth(),
    );
    BackendRuntime.listenable.addListener(_refreshHealth);
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    BackendRuntime.listenable.removeListener(_refreshHealth);
    super.dispose();
  }

  Future<void> _refreshHealth() async {
    final online = await _api.checkHealth(BackendRuntime.config);
    if (!mounted) return;
    setState(() => _rustOnline = online);
  }

  String _roleLabel(AuthSessionState? session) {
    final user = session?.user;
    if (user == null) return 'Guest';
    if (user.isAdmin) return 'Admin';
    if (user.isEmployee) return 'Cleaner';
    if (user.isClient) return 'Client';
    return 'Unknown';
  }

  Widget _chip({required String label, required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: BackendRuntime.listenable,
      builder: (context, config, _) {
        return ValueListenableBuilder(
          valueListenable: AuthSession.listenable,
          builder: (context, session, _) {
            final role = _roleLabel(session);
            final email = session?.loginEmail?.trim();
            final userLabel = email == null || email.isEmpty ? 'none' : email;

            return Container(
              height: widget.preferredSize.height,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(238, 234, 247, 1),
                border: Border(
                  top: const BorderSide(
                    color: Color.fromRGBO(213, 205, 231, 1),
                  ),
                  bottom: const BorderSide(
                    color: Color.fromRGBO(213, 205, 231, 1),
                  ),
                ),
              ),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Image.asset(
                        'assets/images/sub_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _chip(
                    label: _rustOnline ? 'Rust: Online' : 'Rust: Offline',
                    bg: _rustOnline
                        ? Colors.green.shade100
                        : Colors.red.shade100,
                    fg: _rustOnline
                        ? Colors.green.shade900
                        : Colors.red.shade900,
                  ),
                  const SizedBox(width: 8),
                  _chip(
                    label: 'Host: ${config.baseUrl}',
                    bg: Colors.white,
                    fg: const Color.fromRGBO(104, 88, 147, 1),
                  ),
                  const SizedBox(width: 8),
                  _chip(
                    label: 'Role: $role',
                    bg: Colors.white,
                    fg: const Color.fromRGBO(104, 88, 147, 1),
                  ),
                  const SizedBox(width: 8),
                  _chip(
                    label: 'User: $userLabel',
                    bg: Colors.white,
                    fg: const Color.fromRGBO(104, 88, 147, 1),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
