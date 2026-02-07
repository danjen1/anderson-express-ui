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

  static BackendConfig fromEnvironment() {
    const backendValue = String.fromEnvironment(
      'BACKEND',
      defaultValue: 'rust',
    );
    const overrideUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: '',
    );

    final kind = switch (backendValue.toLowerCase()) {
      'python' => BackendKind.python,
      'vapor' => BackendKind.vapor,
      _ => BackendKind.rust,
    };

    return switch (kind) {
      BackendKind.rust => BackendConfig(
        kind: kind,
        baseUrl: overrideUrl.isNotEmpty ? overrideUrl : 'http://localhost:9000',
        healthPath: '/api/v1/healthz',
        employeesPath: '/api/v1/employees',
      ),
      BackendKind.python => BackendConfig(
        kind: kind,
        baseUrl: overrideUrl.isNotEmpty ? overrideUrl : 'http://localhost:8000',
        healthPath: '/api/v1/healthz',
        employeesPath: '/api/v1/employees',
      ),
      BackendKind.vapor => BackendConfig(
        kind: kind,
        baseUrl: overrideUrl.isNotEmpty ? overrideUrl : 'http://localhost:9001',
        healthPath: '/api/v1/healthz',
        employeesPath: '/api/v1/employees',
      ),
    };
  }
}
