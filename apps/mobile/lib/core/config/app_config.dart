class AppConfig {
  const AppConfig({required this.apiBaseUrl, required this.privacyPolicyUrl});

  final String apiBaseUrl;

  /// Public privacy policy. Override with --dart-define=SKP_PRIVACY_POLICY_URL=...
  /// before a store build if this page is hosted elsewhere.
  final String privacyPolicyUrl;

  static const current = AppConfig(
    apiBaseUrl: String.fromEnvironment(
      'SKP_API_BASE_URL',
      defaultValue: 'https://uat-kiosk-api.immortaltechnovation.com/v1',
    ),
    privacyPolicyUrl: String.fromEnvironment(
      'SKP_PRIVACY_POLICY_URL',
      defaultValue: 'https://immortaltechnovation.com/privacy',
    ),
  );
}
