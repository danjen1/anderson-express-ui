import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../services/app_env.dart';
import '../services/auth_session.dart';
import '../utils/error_text.dart';
import '../widgets/backend_banner.dart';
import '../widgets/theme_toggle_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const Color _lightPrimary = Color(0xFF296273);
  static const Color _lightSecondary = Color(0xFFA8D6F7);
  static const Color _lightAccent = Color(0xFF442E6F);
  static const Color _lightCta = Color(0xFFEE7E32);
  static const Color _lightNature = Color(0xFF49A07D);

  static const Color _darkBg = Color(0xFF2C2C2C);
  static const Color _darkText = Color(0xFFE4E4E4);
  static const Color _darkAccent1 = Color(0xFFA8DADC);
  static const Color _darkAccent2 = Color(0xFFFFC1CC);
  static const Color _darkCta = Color(0xFFB39CD0);

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _inlineError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginAsDemoRole({
    required String email,
    required String password,
  }) async {
    _emailController.text = email;
    _passwordController.text = password;
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
      final nextRoute = user.isAdmin ? '/admin' : '/home';
      Navigator.pushReplacementNamed(context, nextRoute);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _inlineError = userFacingError(error);
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
    final titleColor = dark ? _darkAccent1 : _lightPrimary;
    return Scaffold(
      bottomNavigationBar: const SafeArea(top: false, child: BackendBanner()),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? const [_darkBg, _darkBg, Color(0xFF36343B)]
                : const [Colors.white, _lightSecondary, Color(0xFFE7F3FB)],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(
                  children: [
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: dark ? const Color(0xFF383838) : Colors.white,
                        border: Border.all(
                          color: dark ? _darkCta : _lightPrimary,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Image.asset('assets/images/logo.png'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Preview Login',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                        ),
                      ),
                    ),
                    const ThemeToggleButton(),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Card(
                        color: dark ? const Color(0xFF333333) : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: dark ? _darkCta : _lightPrimary,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  height: 178,
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
                                      color: titleColor,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Center(
                                child: RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    style: GoogleFonts.montserrat(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'In Touch ',
                                        style: TextStyle(
                                          color: dark
                                              ? _darkAccent1
                                              : _lightPrimary,
                                        ),
                                      ),
                                      TextSpan(
                                        text: 'With Nature',
                                        style: TextStyle(
                                          color: dark
                                              ? _darkAccent2
                                              : _lightNature,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Sign in',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: dark ? _darkText : _lightAccent,
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
                                      autofillHints: const [
                                        AutofillHints.username,
                                      ],
                                      onChanged: (_) =>
                                          setState(() => _inlineError = null),
                                      onSubmitted: (_) =>
                                          FocusScope.of(context).nextFocus(),
                                      decoration: InputDecoration(
                                        labelText: 'Email',
                                        labelStyle: TextStyle(
                                          color: dark
                                              ? _darkAccent1
                                              : _lightPrimary,
                                        ),
                                        filled: true,
                                        fillColor: dark
                                            ? const Color(0xFF3A3A3A)
                                            : Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: BorderSide(
                                            color: dark
                                                ? _darkCta
                                                : _lightPrimary,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: BorderSide(
                                            color: dark
                                                ? _darkCta
                                                : _lightPrimary,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: BorderSide(
                                            color: dark
                                                ? _darkAccent1
                                                : _lightAccent,
                                            width: 1.6,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    TextField(
                                      controller: _passwordController,
                                      obscureText: true,
                                      textInputAction: TextInputAction.done,
                                      autofillHints: const [
                                        AutofillHints.password,
                                      ],
                                      onChanged: (_) =>
                                          setState(() => _inlineError = null),
                                      onSubmitted: (_) => _login(),
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        labelStyle: TextStyle(
                                          color: dark
                                              ? _darkAccent1
                                              : _lightPrimary,
                                        ),
                                        filled: true,
                                        fillColor: dark
                                            ? const Color(0xFF3A3A3A)
                                            : Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: BorderSide(
                                            color: dark
                                                ? _darkCta
                                                : _lightPrimary,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: BorderSide(
                                            color: dark
                                                ? _darkCta
                                                : _lightPrimary,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: BorderSide(
                                            color: dark
                                                ? _darkAccent1
                                                : _lightAccent,
                                            width: 1.6,
                                          ),
                                        ),
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
                                    color: dark
                                        ? const Color(0xFF3A2F30)
                                        : const Color(0xFFFDECE9),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: dark ? _darkAccent2 : _lightCta,
                                    ),
                                  ),
                                  child: Text(
                                    _inlineError!,
                                    style: TextStyle(
                                      color: dark ? _darkAccent2 : _lightCta,
                                    ),
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
                                    backgroundColor: dark
                                        ? _darkCta
                                        : _lightPrimary,
                                    foregroundColor: dark
                                        ? const Color(0xFF222222)
                                        : Colors.white,
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
                                  style: TextButton.styleFrom(
                                    foregroundColor: dark
                                        ? _darkAccent1
                                        : _lightPrimary,
                                  ),
                                  child: const Text('Open Registration Invite'),
                                ),
                              ),
                              if (AppEnv.isDemoMode ||
                                  AppEnv.isDevelopment) ...[
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: dark
                                        ? const Color(0xFF34343B)
                                        : const Color(0xFFEAF5FC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: dark ? _darkCta : _lightNature,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        AppEnv.isDemoMode
                                            ? 'Quick Demo Role Access (No Password Entry)'
                                            : 'Quick Local Role Access',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: dark
                                              ? _darkAccent1
                                              : _lightPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        alignment: WrapAlignment.center,
                                        spacing: 10,
                                        runSpacing: 8,
                                        children: [
                                          SizedBox(
                                            width: 116,
                                            child: OutlinedButton(
                                              onPressed: _loading
                                                  ? null
                                                  : () => _loginAsDemoRole(
                                                      email:
                                                          'admin@andersonexpress.com',
                                                      password: 'dev-password',
                                                    ),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: dark
                                                    ? _darkAccent1
                                                    : _lightPrimary,
                                                side: BorderSide(
                                                  color: dark
                                                      ? _darkAccent1
                                                      : _lightPrimary,
                                                ),
                                                visualDensity:
                                                    VisualDensity.compact,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 9,
                                                    ),
                                                textStyle: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              child: const Text('Admin'),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 116,
                                            child: OutlinedButton(
                                              onPressed: _loading
                                                  ? null
                                                  : () => _loginAsDemoRole(
                                                      email:
                                                          'john@andersonexpress.com',
                                                      password: 'worker123',
                                                    ),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: dark
                                                    ? _darkAccent1
                                                    : _lightPrimary,
                                                side: BorderSide(
                                                  color: dark
                                                      ? _darkAccent1
                                                      : _lightPrimary,
                                                ),
                                                visualDensity:
                                                    VisualDensity.compact,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 9,
                                                    ),
                                                textStyle: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              child: const Text('Employee'),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 116,
                                            child: OutlinedButton(
                                              onPressed: _loading
                                                  ? null
                                                  : () => _loginAsDemoRole(
                                                      email:
                                                          'contact@techstartup.com',
                                                      password: 'client123',
                                                    ),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: dark
                                                    ? _darkAccent1
                                                    : _lightPrimary,
                                                side: BorderSide(
                                                  color: dark
                                                      ? _darkAccent1
                                                      : _lightPrimary,
                                                ),
                                                visualDensity:
                                                    VisualDensity.compact,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 9,
                                                    ),
                                                textStyle: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              child: const Text('Client'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
