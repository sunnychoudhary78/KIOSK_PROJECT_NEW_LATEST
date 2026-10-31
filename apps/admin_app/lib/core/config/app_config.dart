class AppConfig {
  const AppConfig({required this.apiBaseUrl});

  final String apiBaseUrl;

  static const current = AppConfig(
    apiBaseUrl: String.fromEnvironment(
      'SKP_API_BASE_URL',
      defaultValue: 'https://uat-kiosk-api.immortaltechnovation.com/v1',
    ),
  );
}
