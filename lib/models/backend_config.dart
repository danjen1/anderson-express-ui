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

    return forKind(
      BackendKind.rust,
      host: hostOverride.isNotEmpty ? hostOverride : 'localhost',
      scheme: 'http',
      overrideUrl: overrideUrl,
    );
  }

  static int _portForKind(BackendKind kind) => switch (kind) {
    BackendKind.rust => 9000,
    _ => 9000,
  };
}
