class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.environment,
    this.printerName = '',
    this.printReversePages = true,
    this.surveillanceSegmentSeconds = 600,
    this.surveillanceWidth = 1280,
    this.surveillanceHeight = 720,
    this.surveillanceFps = 15,
    this.surveillanceBitrate = 1200000,
    this.surveillanceMaxCacheBytes = 30 * 1024 * 1024 * 1024,
  });

  final String apiBaseUrl;
  final String environment;

  /// Optional preferred Windows printer name (substring match).
  /// Empty = auto (default printer, else sole installed printer).
  final String printerName;

  /// When true, PDF pages are printed last→first so face-up trays stack
  /// with page 1 on top. Set `SKP_PRINT_REVERSE_PAGES=false` for face-down.
  final bool printReversePages;

  final int surveillanceSegmentSeconds;
  final int surveillanceWidth;
  final int surveillanceHeight;
  final int surveillanceFps;
  final int surveillanceBitrate;
  final int surveillanceMaxCacheBytes;

  /// DigiLocker OAuth redirect registered with MeriPehchaan (exact match).
  /// Derived from [apiBaseUrl] host so LAN kiosks hit the same backend.
  String get digilockerOAuthCallbackUrl =>
      digilockerCallbackFromApiBase(apiBaseUrl);

  /// Builds `/api/v1/auth/digilocker/callback` on the API host from `apiBaseUrl`.
  static String digilockerCallbackFromApiBase(String apiBaseUrl) {
    final uri = Uri.parse(apiBaseUrl);
    final portSuffix = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$portSuffix/api/v1/auth/digilocker/callback';
  }

  static AppConfig fromEnvironment() {
    const env = String.fromEnvironment('SKP_ENV', defaultValue: 'local');
    const apiBaseUrl = String.fromEnvironment(
      'SKP_API_BASE_URL',
      defaultValue: 'https://uat-kiosk-api.immortaltechnovation.com/v1',
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
    const segmentSeconds = int.fromEnvironment(
      'SKP_SURVEILLANCE_SEGMENT_SECONDS',
      defaultValue: 600,
    );
    const width = int.fromEnvironment(
      'SKP_SURVEILLANCE_WIDTH',
      defaultValue: 1280,
    );
    const height = int.fromEnvironment(
      'SKP_SURVEILLANCE_HEIGHT',
      defaultValue: 720,
    );
    const fps = int.fromEnvironment('SKP_SURVEILLANCE_FPS', defaultValue: 15);
    const bitrate = int.fromEnvironment(
      'SKP_SURVEILLANCE_BITRATE',
      defaultValue: 1200000,
    );
    const maxCacheGb = int.fromEnvironment(
      'SKP_SURVEILLANCE_MAX_CACHE_GB',
      defaultValue: 30,
    );
    return AppConfig(
      apiBaseUrl: apiBaseUrl,
      environment: env,
      printerName: printerName,
      printReversePages: printReversePages,
      surveillanceSegmentSeconds: segmentSeconds,
      surveillanceWidth: width,
      surveillanceHeight: height,
      surveillanceFps: fps,
      surveillanceBitrate: bitrate,
      surveillanceMaxCacheBytes: maxCacheGb * 1024 * 1024 * 1024,
    );
  }
}
