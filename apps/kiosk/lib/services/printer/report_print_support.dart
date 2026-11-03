import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/core/network/user_facing_error.dart';
import 'package:skp_kiosk/services/printer/print_coordinator.dart';
import 'package:skp_kiosk/services/printer/print_job_support.dart';
import 'package:skp_kiosk/services/printer/print_status_body.dart';

enum ReportPrintPhase {
  idle,
  preparingPreview,
  previewing,
  printing,
  printResult,
}

class ReportPrintSnapshot {
  const ReportPrintSnapshot({
    this.phase = ReportPrintPhase.idle,
    this.previewTitle,
    this.previewBytes,
    this.previewFilePath,
    this.previewJobId,
    this.pagesExpected = 1,
    this.printFailures = 0,
    this.printConfirmed = false,
    this.paperOut = false,
    this.message,
    this.error,
  });

  final ReportPrintPhase phase;
  final String? previewTitle;
  final Uint8List? previewBytes;
  final String? previewFilePath;
  final String? previewJobId;
  final int pagesExpected;
  final int printFailures;
  final bool printConfirmed;
  final bool paperOut;
  final String? message;
  final String? error;

  bool get isActive => phase != ReportPrintPhase.idle;

  ReportPrintSnapshot copyWith({
    ReportPrintPhase? phase,
    String? previewTitle,
    Uint8List? previewBytes,
    String? previewFilePath,
    String? previewJobId,
    int? pagesExpected,
    int? printFailures,
    bool? printConfirmed,
    bool? paperOut,
    String? message,
    bool clearMessage = false,
    String? error,
    bool clearError = false,
  }) {
    return ReportPrintSnapshot(
      phase: phase ?? this.phase,
      previewTitle: previewTitle ?? this.previewTitle,
      previewBytes: previewBytes ?? this.previewBytes,
      previewFilePath: previewFilePath ?? this.previewFilePath,
      previewJobId: previewJobId ?? this.previewJobId,
      pagesExpected: pagesExpected ?? this.pagesExpected,
      printFailures: printFailures ?? this.printFailures,
      printConfirmed: printConfirmed ?? this.printConfirmed,
      paperOut: paperOut ?? this.paperOut,
      message: clearMessage ? null : (message ?? this.message),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ReportPrintSupport {
  ReportPrintSupport({
    required ApiClient api,
    required PrintCoordinator coordinator,
    this.tempFolderName = 'skp_report_print',
  })  : _api = api,
        _coordinator = coordinator;

  final ApiClient _api;
  final PrintCoordinator _coordinator;
  final String tempFolderName;

  Future<ReportPrintSnapshot> prepare({
    required String createJobPath,
    required Map<String, dynamic> body,
    ReportPrintSnapshot previous = const ReportPrintSnapshot(),
  }) async {
    try {
      final job = await _api.post(createJobPath, body: body);
      final jobId = job['id'] as String;
      final title = job['title'] as String? ?? 'Report';
      final pagesExpected = (job['pagesExpected'] as num?)?.toInt() ??
          (job['pageCount'] as num?)?.toInt() ??
          1;
      final bytes = await _api.getBytes('/print-jobs/$jobId/content');

      final dir = Directory(p.join(Directory.systemTemp.path, tempFolderName));
      await dir.create(recursive: true);
      final filePath = p.join(dir.path, '$jobId.pdf');
      await File(filePath).writeAsBytes(bytes, flush: true);

      return ReportPrintSnapshot(
        phase: ReportPrintPhase.previewing,
        previewTitle: title,
        previewBytes: bytes,
        previewFilePath: filePath,
        previewJobId: jobId,
        pagesExpected: pagesExpected,
        printFailures: previous.printFailures,
      );
    } catch (error) {
      final message = userFacingError(error);
      // Stay in an active print phase so the shell shows a failure UI instead of
      // silently bouncing back to the feature result screen.
      return ReportPrintSnapshot(
        phase: ReportPrintPhase.printResult,
        printFailures: previous.printFailures,
        printConfirmed: false,
        message: message,
        error: message,
        paperOut: error is ApiException && error.code == 'printing_paused',
      );
    }
  }

  Future<ReportPrintSnapshot> confirm({
    required ReportPrintSnapshot current,
    void Function(String message)? onProgress,
  }) async {
    final bytes = current.previewBytes;
    final jobId = current.previewJobId;
    final title = current.previewTitle ?? 'Report';
    if (bytes == null || jobId == null) {
      return current;
    }
    final failures = current.printFailures;

    try {
      final outcome = await _coordinator.printAndReconcile(
        jobId: jobId,
        title: title,
        pdfBytes: bytes,
        pagesExpected: current.pagesExpected,
        colorMode: 'color',
        holdForRetry: failures == 0,
        reportStatus: reportStatus,
        onProgress: onProgress,
      );
      if (outcome.isSuccess || outcome.isUncertain) {
        return ReportPrintSnapshot(
          phase: ReportPrintPhase.printResult,
          previewTitle: title,
          previewBytes: bytes,
          previewFilePath: current.previewFilePath,
          previewJobId: jobId,
          pagesExpected: current.pagesExpected,
          printConfirmed: outcome.isSuccess,
          message: outcome.userMessage,
        );
      }
      if (outcome.reconcileDetail == 'paper_out') {
        return current.copyWith(
          phase: ReportPrintPhase.previewing,
          paperOut: true,
          error: outcome.userMessage,
          clearMessage: true,
        );
      }
      return current.copyWith(
        phase: ReportPrintPhase.previewing,
        printFailures: failures + 1,
        error: outcome.userMessage,
        clearMessage: true,
      );
    } catch (error) {
      return current.copyWith(
        phase: ReportPrintPhase.previewing,
        printFailures: failures + 1,
        error: userFacingError(error),
        clearMessage: true,
      );
    }
  }

  Future<void> reportStatus({
    required String jobId,
    required String status,
    String? errorMessage,
    int? pagesReported,
    String? spoolerJobId,
    int? pageCounterBefore,
    int? pageCounterAfter,
    String? reconcileStatus,
    String? reconcileDetail,
    bool? needsAdminReview,
    bool? holdForRetry,
  }) async {
    await _api.patch(
      '/print-jobs/$jobId/status',
      body: printStatusBody(
        status: status,
        errorMessage: errorMessage,
        pagesReported: pagesReported,
        spoolerJobId: spoolerJobId,
        pageCounterBefore: pageCounterBefore,
        pageCounterAfter: pageCounterAfter,
        reconcileStatus: reconcileStatus,
        reconcileDetail: reconcileDetail,
        needsAdminReview: needsAdminReview,
        holdForRetry: holdForRetry,
      ),
    );
  }

  Future<ReportPrintSnapshot> abandonRetry(ReportPrintSnapshot current) async {
    if (current.printFailures != 1 || current.paperOut) return current;
    final jobId = current.previewJobId;
    final next = current.copyWith(printFailures: 2);
    if (jobId == null || jobId.isEmpty) return next;
    try {
      await reportStatus(
        jobId: jobId,
        status: 'failed',
        pagesReported: 0,
        errorMessage: current.error,
      );
    } catch (_) {}
    return next;
  }

  Future<ReportPrintSnapshot> tellStaff(
    ReportPrintSnapshot current,
    ApiClient api,
  ) async {
    final jobId = current.previewJobId;
    if (jobId == null || jobId.isEmpty) return current;
    await PrintJobSupport(api).send(
      jobId: jobId,
      message: current.error ?? 'Print failed',
    );
    return current.copyWith(message: 'We received this. Staff will review.');
  }

  Future<void> reportPagesMissing(ReportPrintSnapshot current, ApiClient api) async {
    final jobId = current.previewJobId;
    if (jobId == null || jobId.isEmpty) return;
    await PrintJobSupport(api).send(
      jobId: jobId,
      message: 'Visitor says the pages were not received.',
    );
  }
}
