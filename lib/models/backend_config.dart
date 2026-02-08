import '../config/api_config.dart';

enum BackendKind { rust, python, vapor }

class BackendConfig {
  const BackendConfig({
    required this.kind,
    required this.baseUrl,
    required this.healthPath,
    required this.employeesPath,
  });

  final BackendKind kind;
  final String baseUrl;
  final String healthPath;
  final String employeesPath;

  String get label => switch (kind) {
    BackendKind.rust => 'Rust',
    _ => 'Rust',
  };

  static BackendConfig forKind(
    BackendKind kind, {
    String host = 'localhost',
    String scheme = 'http',
    String overrideUrl = '',
  }) {
    // Backend switching is deprecated; force Rust as the active backend.
    const resolvedKind = BackendKind.rust;
    final baseUrl = overrideUrl.isNotEmpty
        ? overrideUrl
        : '$scheme://$host:${_portForKind(resolvedKind)}';
    return BackendConfig(
      kind: resolvedKind,
      baseUrl: baseUrl,
      healthPath: '/healthz',
      employeesPath: '/api/v1/employees',
    );
  }

  static BackendConfig fromEnvironment() {
    const overrideUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: '',
    );
    const hostOverride = String.fromEnvironment(
      'BACKEND_HOST',
      defaultValue: '',
    );

    final trimmedOverride = overrideUrl.trim();
    if (trimmedOverride.isNotEmpty) {
      return forKind(
        BackendKind.rust,
        scheme: 'https',
        overrideUrl: trimmedOverride,
      );
    }
    final trimmedHost = hostOverride.trim();
    if (trimmedHost.isNotEmpty) {
      return forKind(BackendKind.rust, host: trimmedHost, scheme: 'http');
    }
    return forKind(
      BackendKind.rust,
      scheme: 'https',
      overrideUrl: ApiConfig.baseUrl,
    );
  }

  static int _portForKind(BackendKind kind) => switch (kind) {
    BackendKind.rust => 9000,
    _ => 9000,
  };
}
