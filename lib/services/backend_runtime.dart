import '../models/backend_config.dart';
import 'package:flutter/foundation.dart';

class BackendRuntime {
  static const String _debugBackendOverride = String.fromEnvironment(
    'DEBUG_BACKEND_OVERRIDE',
    defaultValue: 'false',
  );
  static BackendConfig _config = BackendConfig.fromEnvironment();
  static final ValueNotifier<BackendConfig> _configNotifier = ValueNotifier(
    _config,
  );

  static BackendConfig get config => _config;
  static ValueListenable<BackendConfig> get listenable => _configNotifier;
  static bool get allowBackendOverride {
    final value = _debugBackendOverride.trim().toLowerCase();
    return value == '1' || value == 'true' || value == 'yes' || value == 'on';
  }

  static void setConfig(BackendConfig next) {
    _config = next;
    _configNotifier.value = next;
  }

  static String get host {
    final uri = Uri.parse(_config.baseUrl);
    return uri.host.isNotEmpty ? uri.host : 'localhost';
  }

  static String get scheme {
    final uri = Uri.parse(_config.baseUrl);
    return uri.scheme.isNotEmpty ? uri.scheme : 'http';
  }

  static String normalizeHostInput(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return host;
    if (value.contains('://')) {
      final uri = Uri.tryParse(value);
      if (uri != null && uri.host.isNotEmpty) {
        return uri.host;
      }
    }
    if (value.contains('/')) {
      final uri = Uri.tryParse('http://$value');
      if (uri != null && uri.host.isNotEmpty) {
        return uri.host;
      }
    }
    if (value.contains(':')) {
      return value.split(':').first.trim();
    }
    return value;
  }
}
