class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.environment,
    this.printerName = '',
    this.printReversePages = true,
    this.printerSnmpHost = '',
    this.printerSnmpVersion = '2c',
    this.printerSnmpCommunity = '',
    this.printReconcileTimeoutMs = 180000,
    this.printerModel = 'Brother HL-L3280CDW',
    this.surveillanceSegmentSeconds = 600,
    this.surveillanceWidth = 1280,
    this.surveillanceHeight = 720,
    this.surveillanceFps = 15,
    this.surveillanceBitrate = 1200000,
    this.surveillanceMaxCacheBytes = 30 * 1024 * 1024 * 1024,
    this.hideCursor = false,
  });

  final String apiBaseUrl;
  final String environment;

  /// Optional preferred Windows printer name (substring match).
  /// Empty = auto (default printer, else sole installed printer).
  final String printerName;

  /// When true, PDF pages are printed last→first so face-up trays stack
  /// with page 1 on top. Set `SKP_PRINT_REVERSE_PAGES=false` for face-down.
  final bool printReversePages;

  /// SNMP host (e.g. `192.168.1.30`). Empty disables SNMP reconciliation.
  final String printerSnmpHost;

  /// Only `2c` is supported in Phase 2.
  final String printerSnmpVersion;

  /// SNMP v2c community. Empty disables SNMP (never commit real secrets).
  final String printerSnmpCommunity;

  /// Max wait for physical page-counter proof before reconciliation_required.
  final int printReconcileTimeoutMs;

  /// Printer profile selector. Only Brother HL-L3280CDW is implemented.
  final String printerModel;

  /// True when host + community are set for SNMP polling.
  bool get snmpConfigured =>
      printerSnmpHost.trim().isNotEmpty && printerSnmpCommunity.trim().isNotEmpty;

  final int surveillanceSegmentSeconds;
  final int surveillanceWidth;
  final int surveillanceHeight;
  final int surveillanceFps;
  final int surveillanceBitrate;
  final int surveillanceMaxCacheBytes;

  /// When true, hide the mouse pointer (touch-only fleet). Default false so
  /// laptop testing still shows a cursor.
  final bool hideCursor;

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
      defaultValue: 'Brother',
    );
    const reverseRaw = String.fromEnvironment(
      'SKP_PRINT_REVERSE_PAGES',
      defaultValue: 'true',
    );
    final printReversePages = reverseRaw.toLowerCase() != 'false';
    // Lab defaults for Brother HL-L3280CDW on LAN. Override with dart-defines
    // in other environments; do not use a non-public community in committed defaults.
    const snmpHost = String.fromEnvironment(
      'SKP_PRINTER_SNMP_HOST',
      defaultValue: '192.168.1.30',
    );
    const snmpVersion = String.fromEnvironment(
      'SKP_PRINTER_SNMP_VERSION',
      defaultValue: '2c',
    );
    const snmpCommunity = String.fromEnvironment(
      'SKP_PRINTER_SNMP_COMMUNITY',
      defaultValue: 'public',
    );
    const reconcileTimeoutMs = int.fromEnvironment(
      'SKP_PRINT_RECONCILE_TIMEOUT_MS',
      defaultValue: 180000,
    );
    const printerModel = String.fromEnvironment(
      'SKP_PRINTER_MODEL',
      defaultValue: 'Brother HL-L3280CDW',
    );
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
    const hideCursorRaw = String.fromEnvironment(
      'SKP_KIOSK_HIDE_CURSOR',
      defaultValue: 'false',
    );
    return AppConfig(
      apiBaseUrl: apiBaseUrl,
      environment: env,
      printerName: printerName,
      printReversePages: printReversePages,
      printerSnmpHost: snmpHost,
      printerSnmpVersion: snmpVersion,
      printerSnmpCommunity: snmpCommunity,
      printReconcileTimeoutMs: reconcileTimeoutMs,
      printerModel: printerModel,
      surveillanceSegmentSeconds: segmentSeconds,
      surveillanceWidth: width,
      surveillanceHeight: height,
      surveillanceFps: fps,
      surveillanceBitrate: bitrate,
      surveillanceMaxCacheBytes: maxCacheGb * 1024 * 1024 * 1024,
      hideCursor: hideCursorRaw.toLowerCase() == 'true',
    );
  }
}
