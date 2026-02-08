import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/app_env.dart';
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
  static const Color _lightPrimary = Color(0xFF296273);
  static const Color _lightSecondary = Color(0xFFA8D6F7);
  static const Color _lightAccent = Color(0xFF442E6F);
  static const Color _lightNature = Color(0xFF49A07D);
  static const Color _darkBg = Color(0xFF2C2C2C);
  static const Color _darkText = Color(0xFFE4E4E4);
  static const Color _darkAccent2 = Color(0xFFFFC1CC);
  static const Color _darkCta = Color(0xFFB39CD0);

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
            final dark = Theme.of(context).brightness == Brightness.dark;
            final bannerBg = dark ? _darkBg : _lightPrimary;
            final borderColor = dark ? _darkCta : _lightAccent;
            final chipBg = dark ? const Color(0xFF3A3A3A) : _lightSecondary;
            final chipFg = dark ? _darkText : _lightAccent;
            final statusBadBg = dark
                ? const Color(0xFF4A3236)
                : const Color(0xFFB42318);
            final statusBadFg = dark ? _darkAccent2 : Colors.white;
            final logoBg = dark ? const Color(0xFF3A3A3A) : Colors.white;

            return Container(
              height: widget.preferredSize.height,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: bannerBg,
                border: Border(
                  top: BorderSide(color: borderColor),
                  bottom: BorderSide(color: borderColor),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: logoBg,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _chip(
                      label: _rustOnline ? 'Rust: Online' : 'Rust: Offline',
                      bg: _rustOnline ? chipBg : statusBadBg,
                      fg: _rustOnline ? chipFg : statusBadFg,
                    ),
                    const SizedBox(width: 8),
                    _chip(
                      label: 'Host: ${config.baseUrl}',
                      bg: chipBg,
                      fg: chipFg,
                    ),
                    const SizedBox(width: 8),
                    _chip(label: 'Role: $role', bg: chipBg, fg: chipFg),
                    const SizedBox(width: 8),
                    _chip(label: 'User: $userLabel', bg: chipBg, fg: chipFg),
                    const SizedBox(width: 8),
                    _chip(
                      label: AppEnv.isDemoMode
                          ? 'Env: ${AppEnv.environment} (Demo)'
                          : 'Env: ${AppEnv.environment}',
                      bg: chipBg,
                      fg: chipFg,
                    ),
                    if (AppEnv.isDemoMode) ...[
                      const SizedBox(width: 8),
                      _chip(
                        label: 'Features in progress',
                        bg: dark ? _darkCta : _lightNature,
                        fg: dark ? _darkBg : Colors.white,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
