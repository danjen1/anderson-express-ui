import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/backend_banner.dart';
import '../widgets/theme_toggle_button.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _api = ApiService();
  bool _loading = false;
  bool _emailLocked = false;

  void _setInviteEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return;
    _emailController.text = email;
    _emailLocked = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setInviteEmail(widget.initialEmail);
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (!_emailLocked && arg is String) _setInviteEmail(arg);
    final linkedEmail = Uri.base.queryParameters['email'];
    if (!_emailLocked) _setInviteEmail(linkedEmail);
    if (!_emailLocked) {
      final fragment = Uri.base.fragment;
      final queryIndex = fragment.indexOf('?');
      if (queryIndex >= 0 && queryIndex < fragment.length - 1) {
        try {
          final query = fragment.substring(queryIndex + 1);
          _setInviteEmail(Uri.splitQueryString(query)['email']);
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
    final canSubmit =
        _emailController.text.trim().isNotEmpty &&
        _passwordController.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anderson Express Cleaning Service'),
        bottom: const BackendBanner(),
        actions: const [ThemeToggleButton()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  height: 148,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  readOnly: true,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Invited Email',
                    helperText: 'Provided by your invitation link',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_emailController.text.trim().isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Open this page from your invitation email link to prefill your invited address.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Set Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _loading || !canSubmit ? null : _register,
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
