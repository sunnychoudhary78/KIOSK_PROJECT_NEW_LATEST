import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/features/otp_print/data/otp_print_repository.dart';
import 'package:skp_kiosk/features/otp_print/domain/otp_redeem_result.dart';
import 'package:skp_kiosk/services/print_spooler.dart';

final printSpoolerProvider = Provider<PrintSpooler>((ref) => ConsolePrintSpooler());

final otpPrintRepositoryProvider = Provider<OtpPrintRepository>((ref) {
  return OtpPrintRepository(ref.watch(apiClientProvider));
});

class OtpPrintController extends AsyncNotifier<OtpRedeemResult?> {
  @override
  Future<OtpRedeemResult?> build() async => null;

  OtpPrintRepository get _repository => ref.read(otpPrintRepositoryProvider);
  PrintSpooler get _spooler => ref.read(printSpoolerProvider);

  Future<void> redeemAndPrint(String code) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await _repository.redeem(code);
      await _repository.reportStatus(jobId: result.printJobId, status: 'printing');
      try {
        if (result.documents.isEmpty) {
          throw StateError('No documents returned for this OTP');
        }
        for (final doc in result.documents) {
          final bytes = await _repository.downloadDocument(doc.contentPath);
          await _spooler.printDocument(
            jobId: result.printJobId,
            title: doc.fileName,
            pdfBytes: bytes,
          );
        }
        await _repository.reportStatus(jobId: result.printJobId, status: 'completed');
      } catch (error) {
        await _repository.reportStatus(
          jobId: result.printJobId,
          status: 'failed',
          errorMessage: error.toString(),
        );
        rethrow;
      }
      return result;
    });
  }
}

final otpPrintControllerProvider =
    AsyncNotifierProvider<OtpPrintController, OtpRedeemResult?>(OtpPrintController.new);
