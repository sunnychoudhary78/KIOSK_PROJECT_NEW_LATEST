class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.environment,
    this.printerName = '',
    this.printReversePages = true,
  });

  final String apiBaseUrl;
  final String environment;

  /// Optional preferred Windows printer name (substring match).
  /// Empty = auto (default printer, else sole installed printer).
  final String printerName;

  /// When true, PDF pages are printed last→first so face-up trays stack
  /// with page 1 on top. Set `SKP_PRINT_REVERSE_PAGES=false` for face-down.
  final bool printReversePages;

  static AppConfig fromEnvironment() {
    const env = String.fromEnvironment('SKP_ENV', defaultValue: 'local');
    const apiBaseUrl = String.fromEnvironment(
      'SKP_API_BASE_URL',
      defaultValue: 'http://localhost:3000/v1',
    );
    const printerName = String.fromEnvironment(
      'SKP_PRINTER_NAME',
      defaultValue: '',
    );
    const reverseRaw = String.fromEnvironment(
      'SKP_PRINT_REVERSE_PAGES',
      defaultValue: 'true',
    );
    final printReversePages = reverseRaw.toLowerCase() != 'false';
    return AppConfig(
      apiBaseUrl: apiBaseUrl,
      environment: env,
      printerName: printerName,
      printReversePages: printReversePages,
    );
  }
}
