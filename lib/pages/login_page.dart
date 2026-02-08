import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/backend_config.dart';
import '../services/api_service.dart';
import '../services/auth_session.dart';
import '../services/backend_runtime.dart';
import '../widgets/backend_banner.dart';
import '../widgets/theme_toggle_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final TextEditingController _hostController;
  bool _loading = false;
  String? _inlineError;

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
          overrideUri != null &&
              overrideUri.hasScheme &&
              overrideUri.host.isNotEmpty
          ? raw
          : '',
    );
    BackendRuntime.setConfig(next);
    setState(() {
      _hostController.text = overrideUri != null && overrideUri.host.isNotEmpty
          ? overrideUri.host
          : normalizedHost;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Backend set to ${next.baseUrl}')));
  }

  Future<void> _developmentBypass() async {
    _emailController.text = 'admin@andersonexpress.com';
    _passwordController.text = 'dev-password';
    await _login();
  }

  Future<void> _login() async {
    if (_loading || !_canSubmit) return;
    final api = ApiService();
    setState(() {
      _loading = true;
      _inlineError = null;
    });
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
      setState(() {
        _inlineError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _canSubmit =>
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: const BackendBanner(),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? const [
                        Color.fromRGBO(19, 24, 23, 1),
                        Color.fromRGBO(24, 34, 31, 1),
                      ]
                    : const [
                        Color.fromRGBO(246, 244, 252, 1),
                        Color.fromRGBO(236, 231, 247, 1),
                      ],
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Image.asset(
                              'assets/images/logo.png',
                              height: 180,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Anderson Express Cleaning Service',
                                maxLines: 1,
                                softWrap: false,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.oregano(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w600,
                                  color: const Color.fromRGBO(26, 64, 47, 1),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Center(
                            child: Text(
                              'In Touch With Nature',
                              textAlign: TextAlign.center,

                              style: GoogleFonts.montserrat(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: const Color.fromRGBO(35, 84, 66, 1),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Sign in',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Color.fromRGBO(104, 88, 147, 1),
                            ),
                          ),
                          const SizedBox(height: 18),
                          AutofillGroup(
                            child: Column(
                              children: [
                                TextField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.username],
                                  onChanged: (_) =>
                                      setState(() => _inlineError = null),
                                  onSubmitted: (_) =>
                                      FocusScope.of(context).nextFocus(),
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: _passwordController,
                                  obscureText: true,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [AutofillHints.password],
                                  onChanged: (_) =>
                                      setState(() => _inlineError = null),
                                  onSubmitted: (_) => _login(),
                                  decoration: const InputDecoration(
                                    labelText: 'Password',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_inlineError != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Text(
                                _inlineError!,
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _loading || !_canSubmit
                                  ? null
                                  : _login,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Login'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: TextButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/register');
                              },
                              child: const Text('Open invite registration'),
                            ),
                          ),
                          const SizedBox(height: 6),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: const EdgeInsets.only(bottom: 8),
                            title: const Text('Developer Tools'),
                            children: [
                              if (BackendRuntime.allowBackendOverride) ...[
                                TextField(
                                  controller: _hostController,
                                  decoration: const InputDecoration(
                                    labelText: 'Backend Host or URL',
                                    hintText:
                                        'archlinux or http://192.168.1.157:9000',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: OutlinedButton(
                                    onPressed: _loading
                                        ? null
                                        : _applyBackendHost,
                                    child: const Text('Apply Host'),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: _loading
                                      ? null
                                      : _developmentBypass,
                                  child: const Text('Development Bypass'),
                                ),
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
          Positioned(
            top: 8,
            right: 8,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: ThemeToggleButton(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
