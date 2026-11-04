import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/network/user_facing_error.dart';
import 'package:skp_kiosk/features/astrology/application/astrology_controller.dart';
import 'package:skp_kiosk/features/astrology/application/astrology_print_mixin.dart';
import 'package:skp_kiosk/features/astrology/data/astrology_repository.dart';
import 'package:skp_kiosk/features/astrology/domain/astrology_insights.dart';
import 'package:skp_kiosk/features/astrology/domain/kundali_phase.dart';
import 'package:skp_kiosk/features/astrology/domain/kundali_result.dart';
import 'package:skp_kiosk/services/printer/print_coordinator.dart';
import 'package:skp_kiosk/services/printer/report_print_support.dart';

class MyKundaliUiState {
  const MyKundaliUiState({
    this.phase = KundaliPhase.form,
    this.result,
    this.error,
    this.subject,
    this.print = const ReportPrintSnapshot(),
  });

  final KundaliPhase phase;
  final KundaliResult? result;
  final String? error;
  final AstrologyBirthSubject? subject;
  final ReportPrintSnapshot print;

  MyKundaliUiState copyWith({
    KundaliPhase? phase,
    KundaliResult? result,
    bool clearResult = false,
    String? error,
    bool clearError = false,
    AstrologyBirthSubject? subject,
    bool clearSubject = false,
    ReportPrintSnapshot? print,
  }) {
    return MyKundaliUiState(
      phase: phase ?? this.phase,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
      subject: clearSubject ? null : (subject ?? this.subject),
      print: print ?? this.print,
    );
  }
}

class MyKundaliController extends Notifier<MyKundaliUiState> {
  Timer? _paymentPoll;

  @override
  MyKundaliUiState build() {
    ref.onDispose(() => _stopPaymentPoll());
    return const MyKundaliUiState();
  }

  AstrologyRepository get _repository => ref.read(astrologyRepositoryProvider);

  ReportPrintSupport get _printSupport => ReportPrintSupport(
        api: ref.read(apiClientProvider),
        coordinator: ref.read(printCoordinatorProvider),
        tempFolderName: 'skp_astrology',
      );

  void _stopPaymentPoll() {
    _paymentPoll?.cancel();
    _paymentPoll = null;
  }

  void _startPaymentPoll() {
    _stopPaymentPoll();
    _paymentPoll = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!ref.mounted) {
        _stopPaymentPoll();
        return;
      }
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
        error: next.error,
        clearError: next.error == null,
      );
    });
  }

  void reset() {
    _stopPaymentPoll();
    state = const MyKundaliUiState();
  }

  Future<void> submit({
    required String name,
    required String gender,
    required String dateOfBirth,
    required String birthTime,
    required String birthPlace,
    required bool birthTimeUnknown,
    required String style,
    double? latitude,
    double? longitude,
  }) async {
    final trimmedName = name.trim();
    final trimmedPlace = birthPlace.trim();
    if (trimmedName.isEmpty || trimmedPlace.length < 2) {
      state = state.copyWith(error: 'Name and birth place are required');
      return;
    }
    if (style != 'north' && style != 'south') {
      state = state.copyWith(error: 'Choose a chart style');
      return;
    }

    final subject = AstrologyBirthSubject(
      name: trimmedName,
      gender: gender,
      dateOfBirth: dateOfBirth,
      birthTime: birthTimeUnknown ? '12:00' : birthTime,
      birthPlace: trimmedPlace,
      birthTimeUnknown: birthTimeUnknown,
    );

    state = state.copyWith(
      phase: KundaliPhase.loading,
      clearError: true,
      clearResult: true,
      subject: subject,
      print: const ReportPrintSnapshot(),
    );

    try {
      final result = await _repository.createKundali(
        KundaliSubmitInput(
          name: trimmedName,
          gender: gender,
          dateOfBirth: dateOfBirth,
          birthTime: birthTimeUnknown ? '12:00' : birthTime,
          birthPlace: trimmedPlace,
          birthTimeUnknown: birthTimeUnknown,
          style: style,
          latitude: latitude,
          longitude: longitude,
        ),
      );
      if (!ref.mounted) {
        return;
      }
      if (result.svg.trim().isEmpty) {
        state = state.copyWith(
          phase: KundaliPhase.form,
          error: 'Could not draw the kundali. Try again.',
        );
        return;
      }
      state = state.copyWith(
        phase: KundaliPhase.result,
        result: result,
        clearError: true,
      );
    } catch (error) {
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(
        phase: KundaliPhase.form,
        error: userFacingError(error),
      );
    }
  }

  /// Print always uses English insights (Helvetica/WinAnsi cannot render Hindi).
  Future<void> preparePrint({
    String chartKey = 'RasiD1',
  }) async {
    if (state.result == null ||
        state.subject == null ||
        state.phase != KundaliPhase.result) {
      return;
    }
    state = state.copyWith(
      clearError: true,
      print: state.print.copyWith(
        phase: ReportPrintPhase.preparingPreview,
        clearError: true,
        clearMessage: true,
        clearPhoneNotice: true,
      ),
    );
    try {
      final options = await _repository.kundaliPrintOptions();
      final chargeRupees = (options['chargeRupees'] as num?)?.toInt() ?? 0;
      if (!ref.mounted) return;
      if (chargeRupees > 0) {
        state = state.copyWith(
          print: state.print.copyWith(
            phase: ReportPrintPhase.choosingPayMethod,
            chargeRupees: chargeRupees,
            amountPaise: chargeRupees * 100,
            clearError: true,
            clearPhoneNotice: true,
          ),
        );
        return;
      }
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        print: state.print.copyWith(
          phase: ReportPrintPhase.printResult,
          printConfirmed: false,
          error: userFacingError(error),
          message: userFacingError(error),
        ),
        error: userFacingError(error),
      );
      return;
    }
    await _runPreparePrint(chartKey: chartKey);
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

  Future<void> choosePayDirect({String chartKey = 'RasiD1'}) async {
    if (state.print.phase != ReportPrintPhase.choosingPayMethod &&
        state.print.phase != ReportPrintPhase.enteringPhone) {
      return;
    }
    await _runPreparePrint(chartKey: chartKey);
  }

  void setPrintPhoneDigits(String value) {
    state = state.copyWith(
      print: state.print.copyWith(phoneDigits: value.replaceAll(RegExp(r'\D'), '')),
    );
  }

  void setPrintOtpDigits(String value) {
    state = state.copyWith(
      print: state.print.copyWith(otpDigits: value.replaceAll(RegExp(r'\D'), '')),
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
      await _repository.requestKundaliPhoneOtp(phone);
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

  Future<void> verifyPrintPhoneOtp({String chartKey = 'RasiD1'}) async {
    if (state.print.phase != ReportPrintPhase.enteringPhone) return;
    final phone = state.print.phoneDigits;
    final otp = state.print.otpDigits;
    if (otp.length < 4) {
      state = state.copyWith(
        print: state.print.copyWith(error: 'Enter the OTP sent to your phone'),
      );
      return;
    }
    state = state.copyWith(
      print: state.print.copyWith(phoneBusy: true, clearError: true),
    );
    try {
      final verified = await _repository.verifyKundaliPhoneOtp(
        phone: phone,
        otp: otp,
      );
      if (!ref.mounted) return;
      final freeEligible = verified['freeEligible'] == true;
      final notice = verified['message']?.toString();
      final token = verified['phoneProofToken']?.toString();
      if (freeEligible && token != null && token.isNotEmpty) {
        state = state.copyWith(
          print: state.print.copyWith(
            phoneBusy: false,
            clearPhoneNotice: true,
            clearError: true,
          ),
        );
        await _runPreparePrint(chartKey: chartKey, phoneProofToken: token);
        return;
      }
      state = state.copyWith(
        print: state.print.copyWith(
          phoneBusy: false,
          phoneNotice: notice ??
              'Free print is not available for this number. Continue with payment.',
          clearError: true,
        ),
      );
      await _runPreparePrint(chartKey: chartKey);
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

  Future<void> _runPreparePrint({
    String chartKey = 'RasiD1',
    String? phoneProofToken,
  }) async {
    final result = state.result;
    final subject = state.subject;
    if (result == null || subject == null) {
      return;
    }
    final tabs = result.availableTabs;
    if (tabs.isEmpty) {
      state = state.copyWith(error: 'No chart available to print');
      return;
    }
    final matched = tabs.where((entry) => entry.key == chartKey);
    final selected = matched.isNotEmpty ? matched.first : tabs.first;
    final charts = [
      {
        'key': selected.key,
        'title': selected.value.title,
        'subtitle': selected.value.subtitle,
        'svg': selected.value.svg,
      },
    ];

    const printLocale = AstrologyInsightLocale.en;
    final bullets =
        result.insights.forChart(selected.key)?.forLocale(printLocale) ??
            const [];
    final insightSections = bullets.isEmpty
        ? const <Map<String, dynamic>>[]
        : [
            {
              'key': selected.key,
              'title': selected.value.title,
              'bullets': bullets,
            },
          ];

    final notice = state.print.phoneNotice;
    state = state.copyWith(
      clearError: true,
      print: state.print.copyWith(
        phase: ReportPrintPhase.preparingPreview,
        clearError: true,
        clearMessage: true,
      ),
    );

    final next = await _printSupport.prepare(
      createJobPath: '/astrology/kundali/print',
      body: {
        'subject': subject.toJson(),
        'style': result.style,
        'chart': {
          if (result.chart.lagna != null) 'lagna': result.chart.lagna,
          if (result.chart.sunSign != null) 'sunSign': result.chart.sunSign,
          if (result.chart.moonSign != null) 'moonSign': result.chart.moonSign,
          if (result.chart.nakshatra != null) 'nakshatra': result.chart.nakshatra,
          if (result.chart.currentDasha != null)
            'currentDasha': result.chart.currentDasha,
        },
        'charts': charts,
        'disclaimer': result.disclaimer,
        'locale': printLocale.apiValue,
        if (insightSections.isNotEmpty) 'insights': insightSections,
        'phoneProofToken': ?phoneProofToken,
      },
      previous: state.print,
    );
    if (!ref.mounted) return;
    final withNotice = next.phase == ReportPrintPhase.awaitingPayment &&
            notice != null &&
            notice.trim().isNotEmpty
        ? next.copyWith(phoneNotice: notice)
        : next;
    state = state.copyWith(
      print: withNotice,
      error: withNotice.error,
      clearError: withNotice.error == null,
    );
    if (withNotice.phase == ReportPrintPhase.awaitingPayment) {
      _startPaymentPoll();
    }
  }

  Future<void> backFromPrintFlow() async {
    final phase = state.print.phase;
    if (phase == ReportPrintPhase.enteringPhone) {
      state = state.copyWith(
        print: state.print.copyWith(
          phase: ReportPrintPhase.choosingPayMethod,
          otpSent: false,
          otpDigits: '',
          phoneBusy: false,
          clearError: true,
          clearPhoneNotice: true,
        ),
      );
      return;
    }
    if (phase == ReportPrintPhase.choosingPayMethod ||
        phase == ReportPrintPhase.awaitingPayment) {
      await cancelPrintPreview();
      return;
    }
    await cancelPrintPreview();
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
        state = state.copyWith(
          print: state.print.copyWith(
            phase: ReportPrintPhase.printing,
            message: message,
          ),
        );
      },
    );
    if (!ref.mounted) return;
    state = state.copyWith(print: next, error: next.error, clearError: next.error == null);
  }

  Future<void> cancelPrintPreview() async {
    _stopPaymentPoll();
    await _printSupport.abandonRetry(state.print);
    if (!ref.mounted) return;
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
}

final myKundaliControllerProvider =
    NotifierProvider.autoDispose<MyKundaliController, MyKundaliUiState>(
  MyKundaliController.new,
);
