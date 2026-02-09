import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../utils/error_text.dart';
import '../widgets/backend_banner.dart';
import '../widgets/theme_toggle_button.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
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
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = dark ? _darkAccent1 : _lightPrimary;
    final canSubmit =
        _emailController.text.trim().isNotEmpty &&
        _passwordController.text.trim().isNotEmpty;
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
                    IconButton(
                      tooltip: 'Back to login',
                      onPressed: () =>
                          Navigator.pushReplacementNamed(context, '/'),
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: dark ? _darkAccent1 : _lightPrimary,
                      ),
                    ),
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
                        'Registration Invite',
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
                                  height: 148,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Anderson Express Cleaning Service',
                                    maxLines: 1,
                                    softWrap: false,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.oregano(
                                      fontSize: 39,
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
                                'Complete Registration',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: dark ? _darkText : _lightAccent,
                                ),
                              ),
                              const SizedBox(height: 18),
                              TextField(
                                controller: _emailController,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  helperText:
                                      'Use the same email address that received your invitation.',

                                  helperStyle: TextStyle(
                                    color: dark ? _darkAccent2 : _lightPrimary,
                                  ),
                                  labelStyle: TextStyle(
                                    color: dark ? _darkAccent1 : _lightPrimary,
                                  ),
                                  filled: true,
                                  fillColor: dark
                                      ? const Color(0xFF3A3A3A)
                                      : Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: dark ? _darkCta : _lightPrimary,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: dark ? _darkCta : _lightPrimary,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: dark ? _darkAccent1 : _lightAccent,
                                      width: 1.6,
                                    ),
                                  ),
                                ),
                              ),
                              if (_emailController.text.trim().isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Use the same email address that received your invitation.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: dark
                                          ? _darkAccent2
                                          : _lightPrimary,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _passwordController,
                                obscureText: true,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: 'Set Password',
                                  labelStyle: TextStyle(
                                    color: dark ? _darkAccent1 : _lightPrimary,
                                  ),
                                  filled: true,
                                  fillColor: dark
                                      ? const Color(0xFF3A3A3A)
                                      : Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: dark ? _darkCta : _lightPrimary,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: dark ? _darkCta : _lightPrimary,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: dark ? _darkAccent1 : _lightAccent,
                                      width: 1.6,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _loading || !canSubmit
                                      ? null
                                      : _register,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: dark
                                        ? _darkCta
                                        : _lightCta,
                                    foregroundColor: dark
                                        ? const Color(0xFF222222)
                                        : Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  child: Text(
                                    _loading
                                        ? 'Registering...'
                                        : 'Complete Registration',
                                  ),
                                ),
                              ),
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
