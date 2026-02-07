import 'package:flutter/foundation.dart';

import '../models/auth_user.dart';

class AuthSessionState {
  const AuthSessionState({
    required this.token,
    required this.user,
    this.loginEmail,
    this.loginPassword,
  });

  final String token;
  final AuthUser user;
  final String? loginEmail;
  final String? loginPassword;
}

class AuthSession {
  static AuthSessionState? _current;
  static final ValueNotifier<AuthSessionState?> _notifier = ValueNotifier(
    _current,
  );

  static AuthSessionState? get current => _current;
  static ValueListenable<AuthSessionState?> get listenable => _notifier;

  static void set(AuthSessionState session) {
    _current = session;
    _notifier.value = session;
  }

  static void clear() {
    _current = null;
    _notifier.value = null;
  }
}
