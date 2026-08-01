class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.environment,
  });

  final String apiBaseUrl;
  final String environment;

  static AppConfig fromEnvironment() {
    const env = String.fromEnvironment('SKP_ENV', defaultValue: 'local');
    const apiBaseUrl = String.fromEnvironment(
      'SKP_API_BASE_URL',
      defaultValue: 'http://localhost:3000/v1',
    );
    return const AppConfig(apiBaseUrl: apiBaseUrl, environment: env);
  }
}
