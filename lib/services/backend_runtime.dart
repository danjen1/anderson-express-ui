import '../models/backend_config.dart';

class BackendRuntime {
  static BackendConfig _config = BackendConfig.fromEnvironment();

  static BackendConfig get config => _config;

  static void setConfig(BackendConfig next) {
    _config = next;
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
