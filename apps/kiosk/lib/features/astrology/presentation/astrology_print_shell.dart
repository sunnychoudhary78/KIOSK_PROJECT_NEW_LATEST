import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/ads/presentation/kiosk_wait_ads.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_hold.dart';
import 'package:skp_kiosk/features/session/presentation/visitor_session_pop_scope.dart';
import 'package:skp_kiosk/services/printer/report_print_support.dart';

/// Shared overlay when an astrology flow is preparing / previewing / printing.
class AstrologyPrintShell extends StatelessWidget {
  const AstrologyPrintShell({
    super.key,
    required this.title,
    required this.print,
    required this.onHome,
    required this.onBackFromPreview,
    required this.onConfirmPrint,
    required this.onTellStaff,
    required this.onClearResult,
    required this.onReportMissing,
  });

  final String title;
  final ReportPrintSnapshot print;
  final Future<void> Function() onHome;
  final Future<void> Function() onBackFromPreview;
  final Future<void> Function() onConfirmPrint;
  final Future<void> Function() onTellStaff;
  final VoidCallback onClearResult;
  final Future<void> Function() onReportMissing;

  @override
  Widget build(BuildContext context) {
    if (print.phase == ReportPrintPhase.preparingPreview) {
      return VisitorSessionPopScope(
        endSessionOnPop: false,
        child: KioskShell(
          title: title,
          onHome: onHome,
          stepLabel: 'Print',
          body: const KioskWaitAds(message: 'Preparing print preview…'),
        ),
      );
    }

    if (print.phase == ReportPrintPhase.previewing ||
        print.phase == ReportPrintPhase.printing) {
      return VisitorSessionPopScope(
        endSessionOnPop: false,
        child: KioskShell(
          title: title,
          onHome: onHome,
          stepLabel: 'Preview',
          footerLeading: KioskGhostButton(
            label: 'Back',
            icon: Icons.arrow_back,
            onPressed: print.phase == ReportPrintPhase.printing
                ? null
                : onBackFromPreview,
          ),
          footerTrailing: print.printFailures >= 2
              ? KioskPrimaryButton(
                  label: 'Tell staff',
                  onPressed: onTellStaff,
                )
              : KioskPrimaryButton(
                  label: print.phase == ReportPrintPhase.printing
                      ? 'Printing…'
                      : 'Print',
                  icon: Icons.print,
                  loading: print.phase == ReportPrintPhase.printing,
                  onPressed: print.phase == ReportPrintPhase.printing
                      ? null
                      : onConfirmPrint,
                ),
          body: print.previewBytes == null
              ? const KioskWaitAds(message: 'Preparing…')
              : KioskPdfPreview(
                  title: print.previewTitle ?? title,
                  pdfBytes: print.previewBytes!,
                  error: print.error,
                ),
        ),
      );
    }

    if (print.phase == ReportPrintPhase.printResult) {
      return VisitorSessionPopScope(
        endSessionOnPop: false,
        child: KioskShell(
          title: title,
          onHome: onHome,
          stepLabel: 'Print',
          body: KioskPrintResult(
            confirmed: print.printConfirmed,
            detail: print.message,
            autoReturn:
                print.printConfirmed ? const Duration(seconds: 20) : null,
            onHome: () async {
              onClearResult();
              await onHome();
            },
            onNotReceived: print.printConfirmed ? onReportMissing : null,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

bool astrologyPrintIsActive(ReportPrintSnapshot print) =>
    print.phase != ReportPrintPhase.idle;

Widget? astrologyPausedShell({
  required WidgetRef ref,
  required ReportPrintSnapshot print,
  required String title,
  required Future<void> Function() onHome,
}) {
  if ((kioskPrintingPaused(ref) || print.paperOut) &&
      print.phase != ReportPrintPhase.printing) {
    return VisitorSessionPopScope(
      endSessionOnPop: false,
      child: KioskShell(
        title: title,
        onHome: onHome,
        body: const KioskPrintingPaused(),
      ),
    );
  }
  return null;
}

void holdSessionForAstrologyPrint(WidgetRef ref, ReportPrintSnapshot print) {
  ref.read(kioskSessionHoldProvider.notifier).set(
        printing: print.phase == ReportPrintPhase.printing,
      );
}
