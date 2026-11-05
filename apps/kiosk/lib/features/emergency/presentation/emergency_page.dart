import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/theme/athena_colors.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/emergency/domain/emergency_contact.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_controller.dart';
import 'package:skp_kiosk/features/session/presentation/visitor_session_pop_scope.dart';

class EmergencyPage extends ConsumerWidget {
  const EmergencyPage({super.key});

  static const _danger = Color(0xFFE11D48);

  Future<void> _endSession(WidgetRef ref) {
    return ref
        .read(kioskSessionControllerProvider.notifier)
        .endVisitorSession(attract: false);
  }

  IconData _iconFor(String key) {
    return switch (key) {
      'police' => Icons.local_police_outlined,
      'fire' => Icons.local_fire_department_outlined,
      'ambulance' => Icons.medical_services_outlined,
      'women' => Icons.woman_outlined,
      'child' => Icons.child_care_outlined,
      'disaster' => Icons.crisis_alert_outlined,
      _ => Icons.sos_outlined,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.athenaColors;
    return VisitorSessionPopScope(
      endSessionOnPop: false,
      child: KioskShell(
        title: 'Emergency',
        onHome: () => _endSession(ref),
        footerLeading: KioskGhostButton(
          label: 'Back',
          icon: Icons.arrow_back,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(32, 12, 32, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Emergency contacts',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: _danger,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Dial from your phone',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.textSecondary,
                    ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: kEmergencyContacts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final contact = kEmergencyContacts[index];
                    return _EmergencyCard(
                      contact: contact,
                      icon: _iconFor(contact.icon),
                      colors: colors,
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

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({
    required this.contact,
    required this.icon,
    required this.colors,
  });

  final EmergencyContact contact;
  final IconData icon;
  final AthenaColors colors;

  static const _danger = Color(0xFFE11D48);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
        border: Border.all(color: _danger.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: colors.cardGlow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
              ),
              child: Icon(icon, color: _danger, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                contact.name,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              contact.phone,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: _danger,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
