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
    BackendKind.python => 'Python',
    BackendKind.vapor => 'Vapor',
  };

  static BackendConfig forKind(
    BackendKind kind, {
    String host = 'localhost',
    String scheme = 'http',
    String overrideUrl = '',
  }) {
    final baseUrl = overrideUrl.isNotEmpty
        ? overrideUrl
        : '$scheme://$host:${_portForKind(kind)}';
    return BackendConfig(
      kind: kind,
      baseUrl: baseUrl,
      healthPath: '/healthz',
      employeesPath: '/api/v1/employees',
    );
  }

  static BackendConfig fromEnvironment() {
    const backendValue = String.fromEnvironment(
      'BACKEND',
      defaultValue: 'rust',
    );
    const overrideUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: '',
    );
    const hostOverride = String.fromEnvironment(
      'BACKEND_HOST',
      defaultValue: '',
    );

    final kind = switch (backendValue.toLowerCase()) {
      'python' => BackendKind.python,
      'vapor' => BackendKind.vapor,
      _ => BackendKind.rust,
    };

    return forKind(
      kind,
      host: hostOverride.isNotEmpty ? hostOverride : 'localhost',
      scheme: 'http',
      overrideUrl: overrideUrl,
    );
  }

  static int _portForKind(BackendKind kind) => switch (kind) {
    BackendKind.rust => 9000,
    BackendKind.python => 8000,
    BackendKind.vapor => 9001,
  };
}
