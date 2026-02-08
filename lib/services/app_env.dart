class AppEnv {
  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static const bool isDemoMode = bool.fromEnvironment(
    'DEMO_MODE',
    defaultValue: false,
  );

  static bool get isPreview => environment.trim().toLowerCase() == 'preview';
}
