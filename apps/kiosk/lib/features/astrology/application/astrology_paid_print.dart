import 'dart:async';

import 'package:skp_kiosk/core/network/user_facing_error.dart';
import 'package:skp_kiosk/services/printer/report_print_support.dart';

/// Result of the phone OTP check before an astrology color print.
class AstrologyPrintQuota {
  const AstrologyPrintQuota({
    required this.freeEligible,
    required this.society,
    required this.productLabel,
    this.remainingColor,
    this.message,
    this.phoneProofToken,
  });

  final bool freeEligible;
  final bool society;
  final String productLabel;
  final int? remainingColor;
  final String? message;
  final String? phoneProofToken;

  String get remainingLabel {
    if (!society) return 'Not on society free list';
    if (remainingColor == null) return 'Unavailable';
    return '$remainingColor free color page${remainingColor == 1 ? '' : 's'} left';
  }

  String get printCostLine => freeEligible
      ? 'This $productLabel print is free for you (uses 1 free color page).'
      : 'This $productLabel print requires payment.';
}

/// Phone OTP, free-quota check, and UPI wait shared by every astrology print.
class AstrologyPaidPrint {
  AstrologyPaidPrint({
    required this.mounted,
    required this.readPrint,
    required this.applyPrint,
    required this.loadChargeRupees,
    required this.sendOtp,
    required this.checkOtp,
    required this.prepareJob,
    required this.pollPayment,
    required this.productLabel,
  });

  final bool Function() mounted;
  final ReportPrintSnapshot Function() readPrint;
  final void Function(ReportPrintSnapshot print) applyPrint;
  final Future<int> Function() loadChargeRupees;
  final Future<void> Function(String phone) sendOtp;
  final Future<Map<String, dynamic>> Function({
    required String phone,
    required String otp,
  }) checkOtp;
  final Future<ReportPrintSnapshot> Function(String? phoneProofToken) prepareJob;
  final Future<ReportPrintSnapshot> Function(ReportPrintSnapshot current) pollPayment;
  final String productLabel;

  Timer? _poll;
  String? _pendingToken;

  void dispose() {
    stopPoll();
  }

  void stopPoll() {
    _poll?.cancel();
    _poll = null;
  }

  void clearPendingToken() {
    _pendingToken = null;
  }

  Future<void> begin() async {
    applyPrint(
      readPrint().copyWith(
        phase: ReportPrintPhase.preparingPreview,
        clearError: true,
        clearMessage: true,
        clearPhoneNotice: true,
      ),
    );
    try {
      final chargeRupees = await loadChargeRupees();
      if (!mounted()) return;
      if (chargeRupees > 0) {
        applyPrint(
          readPrint().copyWith(
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
      if (!mounted()) return;
      final message = userFacingError(error);
      applyPrint(
        readPrint().copyWith(
          phase: ReportPrintPhase.printResult,
          printConfirmed: false,
          error: message,
          message: message,
        ),
      );
      return;
    }
    await submitJob(null);
  }

  Future<void> choosePhone() async {
    if (readPrint().phase != ReportPrintPhase.choosingPayMethod) return;
    applyPrint(
      readPrint().copyWith(
        phase: ReportPrintPhase.enteringPhone,
        otpSent: false,
        otpDigits: '',
        clearError: true,
        clearPhoneNotice: true,
      ),
    );
  }

  Future<void> choosePay() async {
    final phase = readPrint().phase;
    if (phase != ReportPrintPhase.choosingPayMethod &&
        phase != ReportPrintPhase.enteringPhone) {
      return;
    }
    await submitJob(null);
  }

  void setPhoneDigits(String value) {
    applyPrint(
      readPrint().copyWith(phoneDigits: value.replaceAll(RegExp(r'\D'), '')),
    );
  }

  void setOtpDigits(String value) {
    applyPrint(
      readPrint().copyWith(otpDigits: value.replaceAll(RegExp(r'\D'), '')),
    );
  }

  Future<void> requestOtp() async {
    if (readPrint().phase != ReportPrintPhase.enteringPhone) return;
    final phone = readPrint().phoneDigits;
    if (phone.length < 10) {
      applyPrint(
        readPrint().copyWith(error: 'Enter a valid 10-digit mobile number'),
      );
      return;
    }
    applyPrint(readPrint().copyWith(phoneBusy: true, clearError: true));
    try {
      await sendOtp(phone);
      if (!mounted()) return;
      applyPrint(
        readPrint().copyWith(
          phoneBusy: false,
          otpSent: true,
          otpDigits: '',
          clearError: true,
        ),
      );
    } catch (error) {
      if (!mounted()) return;
      applyPrint(
        readPrint().copyWith(
          phoneBusy: false,
          error: userFacingError(error),
        ),
      );
    }
  }

  Future<AstrologyPrintQuota?> verifyOtp() async {
    if (readPrint().phase != ReportPrintPhase.enteringPhone) return null;
    final phone = readPrint().phoneDigits;
    final otp = readPrint().otpDigits;
    if (otp.length < 4) {
      applyPrint(
        readPrint().copyWith(error: 'Enter the OTP sent to your phone'),
      );
      return null;
    }
    applyPrint(readPrint().copyWith(phoneBusy: true, clearError: true));
    try {
      final verified = await checkOtp(phone: phone, otp: otp);
      if (!mounted()) return null;
      final freeEligible = verified['freeEligible'] == true;
      final society = verified['society'] == true;
      final remainingRaw = verified['remainingColor'];
      final remainingColor = remainingRaw is num ? remainingRaw.toInt() : null;
      final notice = verified['message']?.toString();
      final token = verified['phoneProofToken']?.toString();
      _pendingToken =
          freeEligible && token != null && token.isNotEmpty ? token : null;
      applyPrint(
        readPrint().copyWith(
          phoneBusy: false,
          clearError: true,
          clearPhoneNotice: true,
        ),
      );
      return AstrologyPrintQuota(
        freeEligible: freeEligible,
        society: society,
        remainingColor: remainingColor,
        message: notice,
        phoneProofToken: _pendingToken,
        productLabel: productLabel,
      );
    } catch (error) {
      if (!mounted()) return null;
      applyPrint(
        readPrint().copyWith(
          phoneBusy: false,
          error: userFacingError(error),
        ),
      );
      return null;
    }
  }

  Future<void> continueAfterQuota(AstrologyPrintQuota summary) async {
    final token = summary.phoneProofToken ?? _pendingToken;
    if (summary.freeEligible && token != null && token.isNotEmpty) {
      _pendingToken = null;
      applyPrint(readPrint().copyWith(clearPhoneNotice: true, clearError: true));
      await submitJob(token);
      return;
    }
    _pendingToken = null;
    applyPrint(
      readPrint().copyWith(
        phoneNotice: summary.message ??
            'Free print is not available for this number. Continue with payment.',
        clearError: true,
      ),
    );
    await submitJob(null);
  }

  Future<void> submitJob(String? phoneProofToken) async {
    final notice = readPrint().phoneNotice;
    applyPrint(
      readPrint().copyWith(
        phase: ReportPrintPhase.preparingPreview,
        clearError: true,
        clearMessage: true,
      ),
    );
    final next = await prepareJob(phoneProofToken);
    if (!mounted()) return;
    final withNotice = next.phase == ReportPrintPhase.awaitingPayment &&
            notice != null &&
            notice.trim().isNotEmpty
        ? next.copyWith(phoneNotice: notice)
        : next;
    applyPrint(withNotice);
    if (withNotice.phase == ReportPrintPhase.awaitingPayment) {
      startPoll();
    }
  }

  void startPoll() {
    stopPoll();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted()) {
        stopPoll();
        return;
      }
      if (readPrint().phase != ReportPrintPhase.awaitingPayment) {
        stopPoll();
        return;
      }
      final next = await pollPayment(readPrint());
      if (!mounted()) return;
      if (next.phase != ReportPrintPhase.awaitingPayment) {
        stopPoll();
      }
      applyPrint(next);
    });
  }

  /// Back from the phone pad returns to the chooser. Anything else leaves print.
  Future<void> back({required Future<void> Function() cancel}) async {
    if (readPrint().phase == ReportPrintPhase.enteringPhone) {
      applyPrint(
        readPrint().copyWith(
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
    await cancel();
  }
}
