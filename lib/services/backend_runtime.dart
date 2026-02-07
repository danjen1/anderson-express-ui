import '../models/backend_config.dart';
import 'package:flutter/foundation.dart';

class BackendRuntime {
  static BackendConfig _config = BackendConfig.fromEnvironment();
  static final ValueNotifier<BackendConfig> _configNotifier = ValueNotifier(
    _config,
  );

  static BackendConfig get config => _config;
  static ValueListenable<BackendConfig> get listenable => _configNotifier;

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
}
