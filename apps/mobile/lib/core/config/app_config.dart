class AppConfig {
  const AppConfig({required this.apiBaseUrl});

  final String apiBaseUrl;

  static const current = AppConfig(
    apiBaseUrl: String.fromEnvironment(
      'SKP_API_BASE_URL',
      defaultValue: 'http://192.168.1.30:3000/v1',
    ),
  );
}
