import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/hardware/serial/serial_device.dart';
import 'package:skp_kiosk/core/hardware/serial/serial_provider.dart';
import 'package:skp_kiosk/core/hardware/serial/serial_state.dart';
import 'package:skp_kiosk/core/logging/app_logger.dart';
import 'package:skp_kiosk/core/network/user_facing_error.dart';
import 'package:skp_kiosk/features/service_analytics/application/service_analytics_tracker.dart';
import 'package:skp_kiosk/features/service_analytics/domain/service_event_keys.dart';
import 'package:skp_kiosk/features/well_being/application/vitals_line_parser.dart';
import 'package:skp_kiosk/features/well_being/application/well_being_state.dart';
import 'package:skp_kiosk/features/well_being/domain/well_being_mode.dart';
import 'package:skp_kiosk/features/well_being/domain/well_being_phase.dart';
import 'package:skp_kiosk/services/printer/print_coordinator.dart';
import 'package:skp_kiosk/services/printer/report_print_support.dart';

class WellBeingQuotaSummary {
  const WellBeingQuotaSummary({
    required this.freeEligible,
    required this.society,
    required this.colorMode,
    this.remaining,
    this.message,
    this.phoneProofToken,
  });

  final bool freeEligible;
  final bool society;
  final String colorMode;
  final int? remaining;
  final String? message;
  final String? phoneProofToken;

  String get modeLabel => colorMode == 'color' ? 'color' : 'B&W';

  String get remainingLabel {
    if (!society) return 'Not on society free list';
    if (remaining == null) return 'Unavailable';
    return '$remaining free $modeLabel page${remaining == 1 ? '' : 's'} left';
  }

  String get printCostLine => freeEligible
      ? 'This health report print is free for you (uses free $modeLabel pages).'
      : 'This health report print requires payment.';
}

final wellBeingControllerProvider =
    NotifierProvider.autoDispose<WellBeingController, WellBeingUiState>(
  WellBeingController.new,
);

class WellBeingController extends Notifier<WellBeingUiState> {
  final VitalsLineParser _parser = VitalsLineParser();
  StreamSubscription<String>? _incomingSub;
  ProviderSubscription<SerialUiState>? _serialWatch;
  Timer? _paymentPollTimer;

  /// One silent re-start when SpO2 or HR is missing from a complete result.
  bool _oxiAutoRetryUsed = false;

  static const _cmdStop = '{"command":"stop"}';
  static const _cmdStartMax =
      '{"command":"start","sensor":"max30102"}';
  static const _cmdStartTemp =
      '{"command":"start","sensor":"mlx90614"}';

  @override
  WellBeingUiState build() {
    ref.onDispose(() {
      _stopPaymentPoll();
      unawaited(_tearDown(disconnect: true));
    });
    return WellBeingUiState.initial();
  }

  SerialController get _serial => ref.read(serialControllerProvider.notifier);

  ReportPrintSupport get _printSupport => ReportPrintSupport(
        api: ref.read(apiClientProvider),
        coordinator: ref.read(printCoordinatorProvider),
        tempFolderName: 'skp_well_being',
        paymentStatusPath: (jobId) => '/well-being/print-jobs/$jobId/payment',
      );

  void _stopPaymentPoll() {
    _paymentPollTimer?.cancel();
    _paymentPollTimer = null;
  }

  void _armPaymentPoll() {
    _stopPaymentPoll();
    _paymentPollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_pollPaymentOnce());
    });
  }

  Future<void> _pollPaymentOnce() async {
    if (!ref.mounted) return;
    if (state.print.phase != ReportPrintPhase.awaitingPayment) {
      _stopPaymentPoll();
      return;
    }
    final next = await _printSupport.pollPayment(state.print);
    if (!ref.mounted) return;
    if (next.phase != ReportPrintPhase.awaitingPayment) {
      _stopPaymentPoll();
    }
    state = state.copyWith(
      print: next,
      lastError: next.error,
      clearError: next.error == null,
    );
  }

  Future<void> startSession() async {
    if (!ref.mounted || state.sessionActive) {
      return;
    }

    state = state.copyWith(
      sessionActive: true,
      phase: WellBeingPhase.choose,
      activeMode: WellBeingMode.none,
      clearError: true,
      statusMessage: 'Connecting to sensor…',
    );

    _serialWatch?.close();
    _serialWatch = ref.listen<SerialUiState>(serialControllerProvider, (
      previous,
      next,
    ) {
      if (!ref.mounted) {
        return;
      }
      _syncConnection(next);
    });
    _syncConnection(ref.read(serialControllerProvider));

    await _ensureConnected();
    if (!ref.mounted || !state.sessionActive) {
      return;
    }
    await _bindIncoming();
    if (!ref.mounted || !state.sessionActive) {
      return;
    }
    if (ref.mounted && state.isConnected) {
      state = state.copyWith(
        phase: WellBeingPhase.choose,
        statusMessage: 'Choose a measurement',
      );
    }
  }

  Future<void> stopSession() async {
    await _tearDown(disconnect: true);
    if (ref.mounted) {
      state = WellBeingUiState.initial();
    }
  }

  Future<void> retryConnect() async {
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(clearError: true);
    await _ensureConnected();
    if (!ref.mounted || !state.sessionActive) {
      return;
    }
    await _bindIncoming();
  }

  Future<void> startOxygen() async {
    if (!ref.mounted || !state.sessionActive || !state.isConnected) {
      return;
    }
    // ignore: discarded_futures
    ref
        .read(serviceAnalyticsTrackerProvider)
        .track(ServiceEventKeys.wellBeingOxygen);
    _oxiAutoRetryUsed = false;
    state = state.copyWith(
      activeMode: WellBeingMode.oxi,
      phase: WellBeingPhase.oxiIdle,
      fingerDetected: false,
      objectDetected: false,
      collectionTotalSeconds: VitalsLineParser.maxCollectionSeconds,
      secondsRemaining: VitalsLineParser.maxCollectionSeconds,
      measurePct: 0,
      clearLiveHeartRate: true,
      clearLiveSpO2: true,
      clearFinalHeartRate: true,
      clearFinalSpO2: true,
      clearLiveTempC: true,
      clearLiveTempF: true,
      clearFinalTempC: true,
      clearFinalTempF: true,
      clearError: true,
      statusMessage: 'Place your finger gently on the sensor',
    );
    await _sendCommand(_cmdStartMax);
  }

  Future<void> startTemperature() async {
    if (!ref.mounted || !state.sessionActive || !state.isConnected) {
      return;
    }
    // ignore: discarded_futures
    ref
        .read(serviceAnalyticsTrackerProvider)
        .track(ServiceEventKeys.wellBeingTemperature);
    state = state.copyWith(
      activeMode: WellBeingMode.temp,
      phase: WellBeingPhase.tempIdle,
      fingerDetected: false,
      objectDetected: false,
      collectionTotalSeconds: VitalsLineParser.tempCollectionSeconds,
      secondsRemaining: VitalsLineParser.tempCollectionSeconds,
      measurePct: 0,
      clearLiveHeartRate: true,
      clearLiveSpO2: true,
      clearFinalHeartRate: true,
      clearFinalSpO2: true,
      clearLiveTempC: true,
      clearLiveTempF: true,
      clearFinalTempC: true,
      clearFinalTempF: true,
      clearError: true,
      statusMessage: 'Hold your forehead 1–2 cm from the sensor',
    );
    await _sendCommand(_cmdStartTemp);
  }

  Future<void> returnToHub() async {
    if (!ref.mounted || !state.sessionActive) {
      return;
    }
    await _sendCommand(_cmdStop, silent: true);
    if (!ref.mounted || !state.sessionActive) {
      return;
    }
    state = state.copyWith(
      phase: WellBeingPhase.choose,
      activeMode: WellBeingMode.none,
      fingerDetected: false,
      objectDetected: false,
      collectionTotalSeconds: VitalsLineParser.maxCollectionSeconds,
      secondsRemaining: VitalsLineParser.maxCollectionSeconds,
      measurePct: 0,
      clearLiveHeartRate: true,
      clearLiveSpO2: true,
      clearFinalHeartRate: true,
      clearFinalSpO2: true,
      clearLiveTempC: true,
      clearLiveTempF: true,
      clearFinalTempC: true,
      clearFinalTempF: true,
      print: const ReportPrintSnapshot(),
      statusMessage: state.isConnected
          ? 'Choose a measurement'
          : state.statusMessage,
    );
  }

  /// Starts DigiLocker-parity print monetization (color mode → phone/pay).
  Future<void> preparePrint() async {
    if (state.phase != WellBeingPhase.oxiComplete &&
        state.phase != WellBeingPhase.tempComplete) {
      return;
    }
    _stopPaymentPoll();
    state = state.copyWith(
      print: state.print.copyWith(
        phase: ReportPrintPhase.preparingPreview,
        clearError: true,
        clearMessage: true,
        clearPhoneNotice: true,
      ),
    );
    try {
      final options = await ref.read(apiClientProvider).get('/well-being/print-options');
      if (!ref.mounted) return;
      final bw = (options['bwChargeRupees'] as num?)?.toInt() ?? 0;
      final color = (options['colorChargeRupees'] as num?)?.toInt() ?? 0;
      state = state.copyWith(
        print: state.print.copyWith(
          phase: ReportPrintPhase.choosingColorMode,
          bwChargeRupees: bw,
          colorChargeRupees: color,
          clearError: true,
          clearPhoneNotice: true,
        ),
      );
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        print: state.print.copyWith(
          phase: ReportPrintPhase.printResult,
          printConfirmed: false,
          error: userFacingError(error),
          message: userFacingError(error),
        ),
        lastError: userFacingError(error),
      );
    }
  }

  Future<void> chooseColorMode(String mode) async {
    if (state.print.phase != ReportPrintPhase.choosingColorMode) return;
    if (mode != 'bw' && mode != 'color') return;
    final charge = mode == 'color'
        ? state.print.colorChargeRupees
        : state.print.bwChargeRupees;
    state = state.copyWith(
      print: state.print.copyWith(
        colorMode: mode,
        chargeRupees: charge,
        amountPaise: charge * 100,
        clearError: true,
        clearPhoneNotice: true,
      ),
    );
    if (charge <= 0) {
      await _runPreparePrint();
      return;
    }
    state = state.copyWith(
      print: state.print.copyWith(phase: ReportPrintPhase.choosingPayMethod),
    );
  }

  Future<void> choosePhoneQuota() async {
    if (state.print.phase != ReportPrintPhase.choosingPayMethod) return;
    state = state.copyWith(
      print: state.print.copyWith(
        phase: ReportPrintPhase.enteringPhone,
        otpSent: false,
        otpDigits: '',
        clearError: true,
        clearPhoneNotice: true,
      ),
    );
  }

  Future<void> choosePayDirect() async {
    if (state.print.phase != ReportPrintPhase.choosingPayMethod &&
        state.print.phase != ReportPrintPhase.enteringPhone) {
      return;
    }
    await _runPreparePrint();
  }

  void setPrintPhoneDigits(String value) {
    state = state.copyWith(
      print: state.print.copyWith(
        phoneDigits: value.replaceAll(RegExp(r'\D'), ''),
      ),
    );
  }

  void setPrintOtpDigits(String value) {
    state = state.copyWith(
      print: state.print.copyWith(
        otpDigits: value.replaceAll(RegExp(r'\D'), ''),
      ),
    );
  }

  Future<void> requestPrintPhoneOtp() async {
    if (state.print.phase != ReportPrintPhase.enteringPhone) return;
    final phone = state.print.phoneDigits;
    if (phone.length < 10) {
      state = state.copyWith(
        print: state.print.copyWith(error: 'Enter a valid 10-digit mobile number'),
      );
      return;
    }
    state = state.copyWith(
      print: state.print.copyWith(phoneBusy: true, clearError: true),
    );
    try {
      await ref.read(apiClientProvider).post(
        '/well-being/otp-request',
        body: {'phone': phone},
      );
      if (!ref.mounted) return;
      state = state.copyWith(
        print: state.print.copyWith(
          phoneBusy: false,
          otpSent: true,
          otpDigits: '',
          clearError: true,
        ),
      );
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        print: state.print.copyWith(
          phoneBusy: false,
          error: userFacingError(error),
        ),
      );
    }
  }

  Future<WellBeingQuotaSummary?> verifyPrintPhoneOtp() async {
    if (state.print.phase != ReportPrintPhase.enteringPhone) return null;
    final phone = state.print.phoneDigits;
    final otp = state.print.otpDigits;
    final colorMode = state.print.colorMode;
    if (otp.length < 4) {
      state = state.copyWith(
        print: state.print.copyWith(error: 'Enter the OTP sent to your phone'),
      );
      return null;
    }
    state = state.copyWith(
      print: state.print.copyWith(phoneBusy: true, clearError: true),
    );
    try {
      final verified = await ref.read(apiClientProvider).post(
        '/well-being/otp-verify',
        body: {
          'phone': phone,
          'otp': otp,
          'colorMode': colorMode,
        },
      );
      if (!ref.mounted) return null;
      final freeEligible = verified['freeEligible'] == true;
      final society = verified['society'] == true;
      final remainingRaw = verified['remaining'];
      final remaining = remainingRaw is num ? remainingRaw.toInt() : null;
      final notice = verified['message']?.toString();
      final token = verified['phoneProofToken']?.toString();
      state = state.copyWith(
        print: state.print.copyWith(
          phoneBusy: false,
          clearError: true,
          clearPhoneNotice: true,
          phoneProofToken:
              freeEligible && token != null && token.isNotEmpty ? token : null,
          clearPhoneProofToken:
              !(freeEligible && token != null && token.isNotEmpty),
        ),
      );
      return WellBeingQuotaSummary(
        freeEligible: freeEligible,
        society: society,
        colorMode: colorMode,
        remaining: remaining,
        message: notice,
        phoneProofToken:
            freeEligible && token != null && token.isNotEmpty ? token : null,
      );
    } catch (error) {
      if (!ref.mounted) return null;
      state = state.copyWith(
        print: state.print.copyWith(
          phoneBusy: false,
          error: userFacingError(error),
        ),
      );
      return null;
    }
  }

  Future<void> continueAfterQuotaSummary(WellBeingQuotaSummary summary) async {
    final token = summary.phoneProofToken ?? state.print.phoneProofToken;
    if (summary.freeEligible && token != null && token.isNotEmpty) {
      state = state.copyWith(
        print: state.print.copyWith(
          clearPhoneNotice: true,
          clearError: true,
          phoneProofToken: token,
        ),
      );
      await _runPreparePrint(phoneProofToken: token);
      return;
    }
    state = state.copyWith(
      print: state.print.copyWith(
        phoneNotice: summary.message ??
            'Free print is not available for this number. Continue with payment.',
        clearError: true,
        clearPhoneProofToken: true,
      ),
    );
    await _runPreparePrint();
  }

  Future<void> _runPreparePrint({String? phoneProofToken}) async {
    if (state.phase != WellBeingPhase.oxiComplete &&
        state.phase != WellBeingPhase.tempComplete) {
      return;
    }
    final mode = state.phase == WellBeingPhase.oxiComplete ? 'oxi' : 'temp';
    final colorMode = state.print.colorMode;
    final token = phoneProofToken ?? state.print.phoneProofToken;
    _stopPaymentPoll();
    state = state.copyWith(
      print: state.print.copyWith(
        phase: ReportPrintPhase.preparingPreview,
        clearError: true,
        clearMessage: true,
      ),
    );
    final next = await _printSupport.prepare(
      createJobPath: '/well-being/print',
      body: {
        'mode': mode,
        'colorMode': colorMode,
        if (token != null && token.isNotEmpty) 'phoneProofToken': token,
        if (state.finalHeartRate != null) 'heartRate': state.finalHeartRate,
        if (state.finalSpO2 != null) 'spo2': state.finalSpO2,
        if (state.finalTempC != null) 'tempC': state.finalTempC,
        if (state.finalTempF != null) 'tempF': state.finalTempF,
        'heartRateInterpretation': state.heartRateInterpretation,
        'spo2Interpretation': state.spo2Interpretation,
        'temperatureInterpretation': state.temperatureInterpretation,
        'measuredAt': DateTime.now().toUtc().toIso8601String(),
      },
      previous: state.print,
    );
    if (!ref.mounted) return;
    state = state.copyWith(
      print: next,
      lastError: next.error,
      clearError: next.error == null,
    );
    if (next.phase == ReportPrintPhase.awaitingPayment) {
      _armPaymentPoll();
    }
  }

  Future<void> confirmPrint() async {
    if (state.print.phase != ReportPrintPhase.previewing) return;
    state = state.copyWith(
      print: state.print.copyWith(phase: ReportPrintPhase.printing),
    );
    final next = await _printSupport.confirm(
      current: state.print,
      onProgress: (message) {
        if (!ref.mounted) return;
        if (state.print.message == message) return;
        state = state.copyWith(
          print: state.print.copyWith(
            phase: ReportPrintPhase.printing,
            message: message,
          ),
        );
      },
    );
    if (!ref.mounted) return;
    state = state.copyWith(print: next, lastError: next.error, clearError: next.error == null);
  }

  Future<void> cancelPrintPreview() async {
    _stopPaymentPoll();
    await _printSupport.abandonRetry(state.print);
    if (!ref.mounted) return;
    state = state.copyWith(print: const ReportPrintSnapshot());
  }

  Future<void> backFromPrintFlow() async {
    final phase = state.print.phase;
    if (phase == ReportPrintPhase.enteringPhone) {
      state = state.copyWith(
        print: state.print.copyWith(
          phase: ReportPrintPhase.choosingPayMethod,
          otpSent: false,
          otpDigits: '',
          clearError: true,
          clearPhoneNotice: true,
        ),
      );
      return;
    }
    if (phase == ReportPrintPhase.choosingPayMethod) {
      state = state.copyWith(
        print: state.print.copyWith(
          phase: ReportPrintPhase.choosingColorMode,
          clearError: true,
          clearPhoneNotice: true,
        ),
      );
      return;
    }
    _stopPaymentPoll();
    state = state.copyWith(print: const ReportPrintSnapshot());
  }

  Future<void> tellStaffPrint() async {
    final next = await _printSupport.tellStaff(state.print, ref.read(apiClientProvider));
    if (!ref.mounted) return;
    state = state.copyWith(print: next);
  }

  Future<void> reportPrintPagesMissing() async {
    await _printSupport.reportPagesMissing(state.print, ref.read(apiClientProvider));
  }

  void clearPrintResult() {
    _stopPaymentPoll();
    state = state.copyWith(print: const ReportPrintSnapshot());
  }

  Future<void> _ensureConnected() async {
    if (!ref.mounted) {
      return;
    }

    final serialState = ref.read(serialControllerProvider);
    if (serialState.isConnected) {
      final portName = serialState.selectedPortName ??
          (serialState.ports.isNotEmpty ? serialState.ports.first.name : null);
      state = state.copyWith(
        connectionStatus: SerialConnectionStatus.connected,
        portName: portName,
        statusMessage: 'Choose a measurement',
      );
      return;
    }

    state = state.copyWith(
      connectionStatus: SerialConnectionStatus.connecting,
      statusMessage: 'Looking for sensor…',
    );

    await _serial.refreshPorts();
    if (!ref.mounted || !state.sessionActive) {
      return;
    }

    final ports = ref.read(serialControllerProvider).ports;
    if (ports.isEmpty) {
      state = state.copyWith(
        connectionStatus: SerialConnectionStatus.error,
        lastError: 'No serial sensor found. Check the USB cable.',
        statusMessage: 'No sensor connected',
      );
      return;
    }

    final preferred = _preferPort(ports);
    _serial.selectPort(preferred);
    await _serial.connect();
    if (!ref.mounted || !state.sessionActive) {
      return;
    }

    final after = ref.read(serialControllerProvider);
    _syncConnection(after);
    if (!after.isConnected) {
      state = state.copyWith(
        connectionStatus: SerialConnectionStatus.error,
        lastError: after.lastError ?? 'Could not open serial port',
        statusMessage: 'Unable to connect to sensor',
      );
    }
  }

  String _preferPort(List<SerialDevice> ports) {
    final selected = ref.read(serialControllerProvider).selectedPortName;
    if (selected != null && ports.any((p) => p.name == selected)) {
      return selected;
    }

    for (final port in ports) {
      final label = port.displayLabel.toLowerCase();
      if (label.contains('cp210') ||
          label.contains('silicon') ||
          label.contains('ch340') ||
          label.contains('usb')) {
        return port.name;
      }
    }
    return ports.first.name;
  }

  void _syncConnection(SerialUiState serial) {
    if (!ref.mounted || !state.sessionActive) {
      return;
    }

    String? statusMessage = state.statusMessage;
    if (serial.isConnected && state.phase == WellBeingPhase.choose) {
      statusMessage = 'Choose a measurement';
    }
    if (serial.status == SerialConnectionStatus.error) {
      statusMessage = 'Sensor connection error';
    }
    if (serial.status == SerialConnectionStatus.disconnected) {
      statusMessage = 'No sensor connected';
    }

    state = state.copyWith(
      connectionStatus: serial.status,
      portName: serial.selectedPortName,
      lastError: serial.lastError,
      clearError: serial.lastError == null,
      statusMessage: statusMessage,
    );
  }

  Future<void> _bindIncoming() async {
    if (!ref.mounted) {
      return;
    }
    await _incomingSub?.cancel();
    if (!ref.mounted || !state.sessionActive) {
      return;
    }
    _parser.reset();
    final service = ref.read(serialServiceProvider);
    _incomingSub = service.incoming.listen(
      _onChunk,
      onError: (Object error) {
        AppLogger.error('Well Being serial stream error', error);
        if (!ref.mounted) {
          return;
        }
        state = state.copyWith(
          connectionStatus: SerialConnectionStatus.error,
          lastError: error.toString(),
          statusMessage: 'Sensor read error',
        );
      },
    );
  }

  void _onChunk(String chunk) {
    if (!ref.mounted || !state.sessionActive) {
      return;
    }
    for (final result in _parser.addChunk(chunk)) {
      _applySample(result);
    }
  }

  void _applySample(VitalsParseResult sample) {
    if (!ref.mounted || !state.sessionActive || !sample.recognized) {
      return;
    }

    if (sample.isReady) {
      AppLogger.info(
        'Sensor ready: max30102=${sample.max30102Ok} mlx90614=${sample.mlx90614Ok}',
      );
      return;
    }

    if (sample.isError) {
      state = state.copyWith(
        lastError: sample.errorMessage,
        statusMessage: _humanError(sample.errorMessage),
      );
      return;
    }

    if (sample.isInfo) {
      return;
    }

    if (state.activeMode == WellBeingMode.oxi) {
      _applyOxiSample(sample);
      return;
    }

    if (state.activeMode == WellBeingMode.temp) {
      _applyTempSample(sample);
    }
  }

  void _applyOxiSample(VitalsParseResult sample) {
    if (state.phase == WellBeingPhase.oxiComplete) {
      return;
    }

    if (sample.isPlaceFinger) {
      state = state.copyWith(
        phase: WellBeingPhase.oxiIdle,
        fingerDetected: false,
        secondsRemaining: VitalsLineParser.maxCollectionSeconds,
        measurePct: 0,
        clearLiveHeartRate: true,
        clearLiveSpO2: true,
        statusMessage: 'Place your finger gently on the sensor',
      );
      return;
    }

    if (sample.isFingerDetected || sample.isSensorStarted) {
      state = state.copyWith(
        phase: WellBeingPhase.oxiMeasuring,
        fingerDetected: true,
        secondsRemaining: VitalsLineParser.maxCollectionSeconds,
        measurePct: 0,
        statusMessage: sample.isFingerDetected
            ? 'Finger detected — starting measurement'
            : 'Keep your finger still',
      );
      return;
    }

    if (sample.isMaxRecording ||
        (sample.isRecording && sample.sensor == null)) {
      final rem = sample.remSeconds?.ceil().clamp(0, 120);
      final total = VitalsLineParser.maxCollectionSeconds;
      final remaining = rem ?? state.secondsRemaining;
      final pct = ((total - remaining) / total * 100).clamp(0.0, 100.0);
      final extending = sample.status == 'spo2_extending';
      state = state.copyWith(
        phase: WellBeingPhase.oxiMeasuring,
        fingerDetected: true,
        secondsRemaining: remaining,
        measurePct: pct,
        statusMessage: extending
            ? 'Hold still — refining oxygen reading…'
            : 'Keep your finger still',
      );
      return;
    }

    if (sample.isFingerRemovedAbort || sample.isNoFingerDetectedAbort) {
      state = state.copyWith(
        phase: WellBeingPhase.oxiIdle,
        fingerDetected: false,
        secondsRemaining: VitalsLineParser.maxCollectionSeconds,
        measurePct: 0,
        clearLiveHeartRate: true,
        clearLiveSpO2: true,
        statusMessage: sample.isNoFingerDetectedAbort
            ? 'No finger detected — place your finger again'
            : 'Finger lost — place your finger again',
      );
      // Firmware aborted; user can place finger again after we re-start.
      unawaited(_sendCommand(_cmdStartMax, silent: true));
      return;
    }

    if (sample.isMaxTimeoutAbort) {
      state = state.copyWith(
        phase: WellBeingPhase.oxiIdle,
        fingerDetected: false,
        secondsRemaining: VitalsLineParser.maxCollectionSeconds,
        measurePct: 0,
        clearLiveHeartRate: true,
        clearLiveSpO2: true,
        lastError: sample.abortReason,
        statusMessage: _humanError(sample.abortReason),
      );
      unawaited(_sendCommand(_cmdStartMax, silent: true));
      return;
    }

    if (sample.isAborted) {
      state = state.copyWith(
        phase: WellBeingPhase.oxiCancelled,
        fingerDetected: false,
        lastError: sample.abortReason,
        statusMessage: _humanError(sample.abortReason),
      );
      return;
    }

    if (sample.isResult) {
      final finalHr = sample.finalHeartRate ?? sample.heartRate;
      final finalSpo2 = sample.finalSpO2 ?? sample.spo2;
      if (finalHr == null && finalSpo2 == null) {
        state = state.copyWith(
          phase: WellBeingPhase.oxiIdle,
          fingerDetected: false,
          clearFinalHeartRate: true,
          clearFinalSpO2: true,
          statusMessage: 'No reading — place your finger again',
        );
        unawaited(_sendCommand(_cmdStartMax, silent: true));
        return;
      }
      if (finalHr != null && finalSpo2 != null) {
        state = state.copyWith(
          phase: WellBeingPhase.oxiComplete,
          fingerDetected: false,
          secondsRemaining: 0,
          measurePct: 100,
          finalHeartRate: finalHr,
          finalSpO2: finalSpo2,
          statusMessage: 'Measurement complete — you may remove your finger',
        );
        AppLogger.info('Oxi result: HR=$finalHr SpO2=$finalSpo2');
        return;
      }
      // Incomplete (HR-only or SpO2-only): one silent auto-retry, then idle.
      if (!_oxiAutoRetryUsed) {
        _oxiAutoRetryUsed = true;
        state = state.copyWith(
          phase: WellBeingPhase.oxiMeasuring,
          fingerDetected: true,
          secondsRemaining: VitalsLineParser.maxCollectionSeconds,
          measurePct: 0,
          clearFinalHeartRate: true,
          clearFinalSpO2: true,
          statusMessage: 'Hold still — recapturing oxygen…',
        );
        AppLogger.info(
          'Oxi incomplete HR=$finalHr SpO2=$finalSpo2 — auto-retry',
        );
        unawaited(_sendCommand(_cmdStartMax, silent: true));
        return;
      }
      state = state.copyWith(
        phase: WellBeingPhase.oxiIdle,
        fingerDetected: false,
        secondsRemaining: VitalsLineParser.maxCollectionSeconds,
        measurePct: 0,
        clearFinalHeartRate: true,
        clearFinalSpO2: true,
        statusMessage:
            'Oxygen/heart rate incomplete — place your finger and try again',
      );
      AppLogger.info(
        'Oxi incomplete after retry HR=$finalHr SpO2=$finalSpo2',
      );
    }
  }

  void _applyTempSample(VitalsParseResult sample) {
    if (state.phase == WellBeingPhase.tempComplete) {
      return;
    }

    if (sample.isPlaceForehead) {
      state = state.copyWith(
        phase: WellBeingPhase.tempIdle,
        objectDetected: false,
        secondsRemaining: VitalsLineParser.tempCollectionSeconds,
        measurePct: 0,
        clearLiveTempC: true,
        clearLiveTempF: true,
        statusMessage: 'Hold your forehead 1–2 cm from the sensor',
      );
      return;
    }

    if (sample.isObjectDetected) {
      state = state.copyWith(
        phase: WellBeingPhase.tempIdle,
        objectDetected: true,
        secondsRemaining: VitalsLineParser.tempCollectionSeconds,
        measurePct: 0,
        statusMessage: 'Forehead detected — starting measurement',
      );
      return;
    }

    if (sample.isSensorStarted) {
      state = state.copyWith(
        phase: WellBeingPhase.tempMeasuring,
        objectDetected: true,
        secondsRemaining: VitalsLineParser.tempCollectionSeconds,
        measurePct: 0,
        statusMessage: 'Hold your forehead still',
      );
      return;
    }

    if (sample.isTempRecording ||
        (sample.isRecording && sample.sensor == null)) {
      final rem = sample.remSeconds?.ceil().clamp(
            0,
            VitalsLineParser.tempCollectionSeconds,
          );
      final total = VitalsLineParser.tempCollectionSeconds;
      final remaining = rem ?? state.secondsRemaining;
      final pct = ((total - remaining) / total * 100).clamp(0.0, 100.0);
      state = state.copyWith(
        phase: WellBeingPhase.tempMeasuring,
        objectDetected: true,
        secondsRemaining: remaining,
        measurePct: pct,
        statusMessage: 'Hold your forehead still',
      );
      return;
    }

    if (sample.isNoObjectDetectedAbort) {
      state = state.copyWith(
        phase: WellBeingPhase.tempIdle,
        objectDetected: false,
        secondsRemaining: VitalsLineParser.tempCollectionSeconds,
        measurePct: 0,
        clearLiveTempC: true,
        clearLiveTempF: true,
        statusMessage: 'No forehead detected — hold closer and try again',
      );
      unawaited(_sendCommand(_cmdStartTemp, silent: true));
      return;
    }

    if (sample.isAborted) {
      state = state.copyWith(
        lastError: sample.abortReason,
        statusMessage: _humanError(sample.abortReason),
        phase: WellBeingPhase.choose,
        activeMode: WellBeingMode.none,
        objectDetected: false,
      );
      return;
    }

    if (sample.isResult) {
      final tempC = sample.temperatureC;
      final tempF = sample.temperatureF;
      if (tempC == null) {
        state = state.copyWith(
          phase: WellBeingPhase.tempIdle,
          objectDetected: false,
          secondsRemaining: VitalsLineParser.tempCollectionSeconds,
          measurePct: 0,
          statusMessage: 'No temperature reading — try again',
          lastError: 'Temperature result missing',
        );
        unawaited(_sendCommand(_cmdStartTemp, silent: true));
        return;
      }
      state = state.copyWith(
        phase: WellBeingPhase.tempComplete,
        objectDetected: false,
        secondsRemaining: 0,
        measurePct: 100,
        finalTempC: tempC,
        finalTempF: tempF,
        liveTempC: tempC,
        liveTempF: tempF,
        statusMessage: 'Temperature captured',
      );
      AppLogger.info('Temp result: ${tempC.toStringAsFixed(1)}°C');
    }
  }

  String _humanError(String? code) {
    return switch (code) {
      'finger_removed' => 'Finger removed during measurement',
      'no_finger_detected' => 'No finger detected in time — try again',
      'no_object_detected' =>
        'No forehead detected — hold closer and try again',
      'max30102_timeout' => 'Pulse sensor timed out — retrying',
      'max30102_recovery_failed' =>
        'Pulse sensor lost connection — retrying',
      'session_timeout' => 'Measurement timed out — please try again',
      'user_stop' => 'Measurement stopped',
      'max30102_not_found' => 'Pulse oximeter sensor not found',
      'mlx90614_not_found' => 'Temperature sensor not found',
      'session_in_progress' => 'A measurement is already in progress',
      'no_sensor_requested' => 'No sensor requested',
      'unknown_sensor' || 'unknown_command' => 'Sensor command not understood',
      null || '' => 'Sensor error',
      _ => code,
    };
  }

  Future<void> _sendCommand(String command, {bool silent = false}) async {
    if (!ref.mounted) {
      return;
    }
    final serial = ref.read(serialControllerProvider);
    if (!serial.isConnected) {
      return;
    }
    try {
      await _serial.sendLine(command);
    } catch (error) {
      AppLogger.error('Well Being command failed: $command', error);
      if (!silent && ref.mounted) {
        state = state.copyWith(
          lastError: error.toString(),
          statusMessage: 'Could not talk to sensor',
        );
      }
    }
  }

  Future<void> _tearDown({required bool disconnect}) async {
    _stopPaymentPoll();
    var shouldDisconnect = false;
    Future<void> Function()? doDisconnect;
    try {
      shouldDisconnect = disconnect && state.sessionActive;
      if (shouldDisconnect && ref.mounted) {
        final controller = ref.read(serialControllerProvider.notifier);
        try {
          if (ref.read(serialControllerProvider).isConnected) {
            await controller.sendLine(_cmdStop);
          }
        } catch (_) {}
        doDisconnect = controller.disconnect;
      }
    } catch (_) {
      try {
        if (disconnect) {
          final service = ref.read(serialServiceProvider);
          try {
            if (service.isConnected) {
              await service.sendLine(_cmdStop);
            }
          } catch (_) {}
          doDisconnect = () => service.disconnect(silent: true);
          shouldDisconnect = true;
        }
      } catch (_) {
        shouldDisconnect = false;
        doDisconnect = null;
      }
    }

    try {
      _serialWatch?.close();
    } catch (_) {}
    _serialWatch = null;

    final sub = _incomingSub;
    _incomingSub = null;
    try {
      await sub?.cancel();
    } catch (_) {}

    _parser.reset();

    if (shouldDisconnect && doDisconnect != null) {
      try {
        await doDisconnect();
      } catch (error) {
        AppLogger.error('Well Being serial disconnect failed', error);
      }
    }
  }
}
