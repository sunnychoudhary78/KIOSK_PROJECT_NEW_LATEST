import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/theme/athena_colors.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/local_services/domain/local_service.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_controller.dart';
import 'package:skp_kiosk/features/session/presentation/visitor_session_pop_scope.dart';

class LocalServiceContactsPage extends ConsumerWidget {
  const LocalServiceContactsPage({super.key, required this.category});

  final LocalServiceCategory category;

  Future<void> _endSession(WidgetRef ref) {
    return ref.read(kioskSessionControllerProvider.notifier).endVisitorSession(attract: false);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.athenaColors;

    return VisitorSessionPopScope(
      endSessionOnPop: false,
      child: KioskShell(
        title: category.name,
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
                'Name and phone',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: category.contacts.isEmpty
                    ? Center(
                        child: Text(
                          'No numbers in this list.',
                          style: TextStyle(color: colors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        itemCount: category.contacts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return _ContactCard(contact: category.contacts[index]);
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

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.contact});

  final LocalServiceContact contact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.athenaColors;
    final isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF211747), Color(0xFF17102F)],
              )
            : null,
        color: isDark ? null : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF7445BD) : const Color(0xFFE2EBF5),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x2E8B35FF) : const Color(0x0C1B2B4F),
            blurRadius: isDark ? 16 : 10,
            offset: isDark ? Offset.zero : const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
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
              _formatPhone(contact.phone),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: colors.accentMagenta,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 10) {
    final head = digits.substring(0, 5);
    final tail = digits.substring(5);
    return '+91 $head $tail';
  }
  if (digits.length == 12 && digits.startsWith('91')) {
    final head = digits.substring(2, 7);
    final tail = digits.substring(7);
    return '+91 $head $tail';
  }
  return phone;
}
