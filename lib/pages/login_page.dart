import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_session.dart';

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
  final _api = ApiService();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      final token = await _api.fetchToken(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final user = await _api.whoAmI(bearerToken: token);
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
                  onPressed: () {
                    _login();
                  },
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
