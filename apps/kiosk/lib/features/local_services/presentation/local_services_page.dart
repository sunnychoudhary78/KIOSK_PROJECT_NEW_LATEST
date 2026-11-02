import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/app/router.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/local_services/application/local_services_controller.dart';
import 'package:skp_kiosk/features/local_services/domain/local_service.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_controller.dart';
import 'package:skp_kiosk/features/session/presentation/visitor_session_pop_scope.dart';

class LocalServicesPage extends ConsumerStatefulWidget {
  const LocalServicesPage({super.key});

  @override
  ConsumerState<LocalServicesPage> createState() => _LocalServicesPageState();
}

class _LocalServicesPageState extends ConsumerState<LocalServicesPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(localServicesControllerProvider.notifier).load();
    });
  }

  Future<void> _endSession() {
    return ref.read(kioskSessionControllerProvider.notifier).endVisitorSession(attract: false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localServicesControllerProvider);
    return VisitorSessionPopScope(
      child: KioskShell(
        title: 'Find services',
        onHome: _endSession,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose a trade',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _CategoryBody(state: state)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryBody extends StatelessWidget {
  const _CategoryBody({required this.state});

  final LocalServicesState state;

  Widget _cell(BuildContext context, List<LocalServiceCategory> categories, int index) {
    if (index >= categories.length) {
      return const SizedBox.expand();
    }
    final category = categories[index];
    final count = category.contacts.length;
    return _TradeTile(
      icon: _iconFor(category.slug),
      title: category.name,
      subtitle: count == 1 ? '1 number' : '$count numbers',
      onTap: () => Navigator.of(context).pushNamed(
        AppRoutes.localServiceContacts,
        arguments: category,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (state.loading && state.categories.isEmpty) {
      return const KioskLoading(message: 'Loading services…');
    }
    if (state.error != null && state.categories.isEmpty) {
      return Center(
        child: KioskStatusBanner(
          message: state.error!,
          tone: KioskBannerTone.danger,
          icon: Icons.error_outline,
        ),
      );
    }
    if (state.categories.isEmpty) {
      return const Center(child: Text('No services are listed yet.'));
    }
    const columns = 4;
    const gap = 8.0;
    final categories = state.categories;
    final rowCount = (categories.length / columns).ceil();
    return Column(
      children: [
        for (var row = 0; row < rowCount; row++) ...[
          if (row > 0) const SizedBox(height: gap),
          Expanded(
            child: Row(
              children: [
                for (var col = 0; col < columns; col++) ...[
                  if (col > 0) const SizedBox(width: gap),
                  Expanded(child: _cell(context, categories, row * columns + col)),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TradeTile extends StatelessWidget {
  const _TradeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: SkpColors.panel,
      borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
            border: Border.all(color: SkpColors.line, width: SkpTokens.hairline),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 28, color: SkpColors.accent),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: SkpColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

IconData _iconFor(String slug) {
  switch (slug) {
    case 'appliance-repair':
      return Icons.ac_unit_outlined;
    case 'scrap-dealer':
      return Icons.recycling_outlined;
    case 'two-wheeler-mechanic':
      return Icons.two_wheeler_outlined;
    case 'tailor':
      return Icons.checkroom_outlined;
    case 'carpenter':
      return Icons.carpenter_outlined;
    case 'gas-stove-repair':
      return Icons.local_fire_department_outlined;
    case 'electrician':
      return Icons.electrical_services_outlined;
    case 'pigeon-net':
      return Icons.grid_on_outlined;
    case 'puncture':
      return Icons.tire_repair_outlined;
    case 'painter':
      return Icons.format_paint_outlined;
    case 'mason':
      return Icons.foundation_outlined;
    case 'interior':
      return Icons.chair_outlined;
    case 'car-mechanic':
      return Icons.directions_car_outlined;
    case 'key-maker':
      return Icons.key_outlined;
    case 'fabricator':
      return Icons.precision_manufacturing_outlined;
    case 'plumber':
      return Icons.plumbing_outlined;
    default:
      return Icons.handyman_outlined;
  }
}
