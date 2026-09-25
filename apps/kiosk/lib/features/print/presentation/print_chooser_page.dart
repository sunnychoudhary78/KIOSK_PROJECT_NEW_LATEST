import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/app/router.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_controller.dart';
import 'package:skp_kiosk/features/session/presentation/visitor_session_pop_scope.dart';

class PrintChooserPage extends ConsumerWidget {
  const PrintChooserPage({super.key});

  Future<void> _endSession(WidgetRef ref) {
    return ref.read(kioskSessionControllerProvider.notifier).endVisitorSession(attract: false);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return VisitorSessionPopScope(
      child: KioskShell(
        title: 'Print',
        onHome: () => _endSession(ref),
        footerLeading: KioskGhostButton(
          label: 'Cancel',
          onPressed: () => _endSession(ref),
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'How do you want to print?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Use your phone here, or enter the OTP from the mobile app.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: SkpColors.muted),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const gap = 16.0;
                    final tileW = (constraints.maxWidth - gap) / 2;
                    final tileH = constraints.maxHeight;
                    return Row(
                      children: [
                        SizedBox(
                          width: tileW,
                          height: tileH,
                          child: KioskServiceTile(
                            icon: Icons.qr_code_2_outlined,
                            title: 'Print from this phone',
                            subtitle: 'Scan a QR and upload in the browser',
                            onTap: () => Navigator.of(context).pushNamed(AppRoutes.quickPrint),
                          ),
                        ),
                        const SizedBox(width: gap),
                        SizedBox(
                          width: tileW,
                          height: tileH,
                          child: KioskServiceTile(
                            icon: Icons.pin_outlined,
                            title: 'I have an OTP',
                            subtitle: 'Enter the code sent to the mobile app',
                            onTap: () => Navigator.of(context).pushNamed(AppRoutes.otpPrint),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
