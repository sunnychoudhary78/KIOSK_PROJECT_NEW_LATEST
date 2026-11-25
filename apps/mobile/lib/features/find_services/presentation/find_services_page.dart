import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/app/router.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';
import 'package:skp_mobile/core/ui/ui.dart';
import 'package:skp_mobile/features/find_services/application/find_services_controller.dart';
import 'package:skp_mobile/features/find_services/domain/local_service.dart';
import 'package:skp_mobile/l10n/app_localizations.dart';

class FindServicesPage extends ConsumerStatefulWidget {
  const FindServicesPage({super.key});

  @override
  ConsumerState<FindServicesPage> createState() => _FindServicesPageState();
}

class _FindServicesPageState extends ConsumerState<FindServicesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(findServicesProvider.notifier).load();
    });
  }

  void _openCategory(LocalServiceCategory category) {
    Navigator.of(context).pushNamed(
      AppRoutes.findServiceContacts,
      arguments: category,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(findServicesProvider);
    final l10n = AppLocalizations.of(context);

    return SkpScaffold(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkpPageHeader(
            title: l10n.findServicesTitle,
            subtitle: l10n.findServicesHelper,
          ),
          const SizedBox(height: 20),
          if (state.loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.error != null)
            Expanded(
              child: SkpEmptyState(
                icon: Icons.handyman_outlined,
                title: state.error!,
                message: l10n.findServicesHelper,
                actionLabel: l10n.retry,
                onAction: () => ref.read(findServicesProvider.notifier).load(),
              ),
            )
          else if (state.categories.isEmpty)
            Expanded(
              child: SkpEmptyState(
                icon: Icons.handyman_outlined,
                title: l10n.findServicesEmpty,
                message: l10n.findServicesEmptyHelper,
                actionLabel: l10n.refresh,
                secondary: true,
                onAction: () => ref.read(findServicesProvider.notifier).load(),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.read(findServicesProvider.notifier).load(),
                child: GridView.builder(
                  itemCount: state.categories.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.15,
                  ),
                  itemBuilder: (context, index) {
                    final category = state.categories[index];
                    return _ServiceCategoryCard(
                      category: category,
                      contactLabel: l10n.findServicesContactCount(
                        category.contacts.length,
                      ),
                      onTap: () => _openCategory(category),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ServiceCategoryCard extends StatelessWidget {
  const _ServiceCategoryCard({
    required this.category,
    required this.contactLabel,
    required this.onTap,
  });

  final LocalServiceCategory category;
  final String contactLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = category.accent;

    return SkpPanelCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(category.icon, color: accent, size: 24),
          ),
          const Spacer(),
          Text(
            category.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            contactLabel,
            style: theme.textTheme.bodySmall?.copyWith(color: SkpColors.muted),
          ),
        ],
      ),
    );
  }
}
