import 'package:flutter/material.dart';

import '../models/backend_config.dart';
import '../services/api_service.dart';
import '../services/auth_session.dart';
import '../services/backend_runtime.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController(
    text: 'admin@andersonexpress.com',
  );
  final _passwordController = TextEditingController(text: 'dev-password');
  late final TextEditingController _hostController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: BackendRuntime.host);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _hostController.dispose();
    super.dispose();
  }

  void _applyBackendHost() {
    final raw = _hostController.text.trim();
    final normalizedHost = BackendRuntime.normalizeHostInput(raw);
    final overrideUri = raw.contains('://') ? Uri.tryParse(raw) : null;
    final next = BackendConfig.forKind(
      BackendKind.rust,
      host: normalizedHost,
      scheme: BackendRuntime.scheme,
      overrideUrl:
          overrideUri != null && overrideUri.hasScheme && overrideUri.host.isNotEmpty
          ? raw
          : '',
    );
    BackendRuntime.setConfig(next);
    setState(() {
      _hostController.text =
          overrideUri != null && overrideUri.host.isNotEmpty
          ? overrideUri.host
          : normalizedHost;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Backend set to ${next.baseUrl}')),
    );
  }

  Future<void> _developmentBypass() async {
    _emailController.text = 'admin@andersonexpress.com';
    _passwordController.text = 'dev-password';
    await _login();
  }

  Future<void> _login() async {
    final api = ApiService();
    setState(() => _loading = true);
    try {
      final token = await api.fetchToken(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final user = await api.whoAmI(bearerToken: token);
      AuthSession.set(
        AuthSessionState(
          token: token,
          user: user,
          loginEmail: _emailController.text.trim(),
          loginPassword: _passwordController.text,
        ),
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Anderson Express',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Demo Login',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _hostController,
                  decoration: const InputDecoration(
                    labelText: 'Backend Host or URL',
                    hintText: 'archlinux or http://192.168.1.157:9000',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    onPressed: _loading ? null : _applyBackendHost,
                    child: const Text('Apply Host'),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Active backend: ${BackendRuntime.config.baseUrl}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _loading ? null : _login,
                  child: Text(_loading ? 'Logging In...' : 'Login'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/register',
                      arguments: _emailController.text.trim(),
                    );
                  },
                  child: const Text('Register Invite'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _loading ? null : _developmentBypass,
                  child: const Text('Development Bypass'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
