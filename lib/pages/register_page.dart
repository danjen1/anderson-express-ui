import 'package:flutter/material.dart';

import '../services/api_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController(text: 'dev-password');
  final _api = ApiService();
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_emailController.text.isEmpty &&
        widget.initialEmail != null &&
        widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
    }
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (_emailController.text.isEmpty && arg is String && arg.isNotEmpty) {
      _emailController.text = arg;
    }
    final linkedEmail = Uri.base.queryParameters['email'];
    if (_emailController.text.isEmpty &&
        linkedEmail != null &&
        linkedEmail.isNotEmpty) {
      _emailController.text = linkedEmail;
    }
    if (_emailController.text.isEmpty) {
      final fragment = Uri.base.fragment;
      final queryIndex = fragment.indexOf('?');
      if (queryIndex >= 0 && queryIndex < fragment.length - 1) {
        try {
          final query = fragment.substring(queryIndex + 1);
          final queryEmail = Uri.splitQueryString(query)['email'];
          if (queryEmail != null && queryEmail.isNotEmpty) {
            _emailController.text = queryEmail;
          }
        } catch (_) {
          // Ignore malformed fragment query strings.
        }
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() => _loading = true);
    try {
      await _api.registerUser(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration complete. You can now login.'),
        ),
      );
      Navigator.pop(context);
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
      appBar: AppBar(title: const Text('Register Invite')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Invited Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Set Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _loading ? null : _register,
                  child: Text(
                    _loading ? 'Registering...' : 'Complete Registration',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
