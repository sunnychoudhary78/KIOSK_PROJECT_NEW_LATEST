import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_admin/core/theme/app_theme.dart';
import 'package:skp_admin/core/ui/widgets.dart';
import 'package:skp_admin/features/auth/presentation/auth_controller.dart';
import 'package:skp_admin/features/society_phones/data/society_phone.dart';
import 'package:skp_admin/features/society_phones/presentation/society_phones_controller.dart';

class SocietyPhonesPage extends ConsumerStatefulWidget {
  const SocietyPhonesPage({super.key});

  @override
  ConsumerState<SocietyPhonesPage> createState() => _SocietyPhonesPageState();
}

class _SocietyPhonesPageState extends ConsumerState<SocietyPhonesPage> {
  final _search = TextEditingController();
  final _phone = TextEditingController();
  final _bw = TextEditingController();
  final _color = TextEditingController();
  var _period = SocietyQuota.defaults.period;
  var _seeded = false;

  @override
  void initState() {
    super.initState();
    _applyQuota(SocietyQuota.defaults);
    Future.microtask(() => ref.read(societyPhonesProvider.notifier).load());
  }

  @override
  void dispose() {
    _search.dispose();
    _phone.dispose();
    _bw.dispose();
    _color.dispose();
    super.dispose();
  }

  void _applyQuota(SocietyQuota quota) {
    _period = quota.period;
    _bw.text = '${quota.freeBwPages}';
    _color.text = '${quota.freeColorPages}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(societyPhonesProvider);
    final canWrite = ref.watch(staffAuthProvider).canWrite;
    ref.listen(societyPhonesProvider.select((value) => value.quota), (previous, next) {
      if (_seeded && previous == next) return;
      _seeded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _applyQuota(next));
      });
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Society phones')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(societyPhonesProvider.notifier).load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (state.loading && state.items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (state.error != null) ErrorBanner(message: state.error!),
            if (state.notice != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(state.notice!, style: const TextStyle(color: AdminColors.success)),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Free limit', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    const Text(
                      'Listed numbers use this free limit. The kiosk session cap and the night free-disabled window still apply.',
                      style: TextStyle(color: AdminColors.muted),
                    ),
                    const SizedBox(height: 12),
                    const Text('Period', style: TextStyle(color: AdminColors.muted)),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'daily', label: Text('Daily')),
                        ButtonSegment(value: 'weekly', label: Text('Weekly')),
                        ButtonSegment(value: 'monthly', label: Text('Monthly')),
                      ],
                      selected: {_period},
                      onSelectionChanged: canWrite
                          ? (value) => setState(() => _period = value.first)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bw,
                      enabled: canWrite,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Free black-and-white pages'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _color,
                      enabled: canWrite,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Free color pages'),
                    ),
                    if (canWrite) ...[
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: state.savingQuota
                            ? null
                            : () => ref.read(societyPhonesProvider.notifier).saveQuota(
                                  period: _period,
                                  bwRaw: _bw.text,
                                  colorRaw: _color.text,
                                ),
                        child: Text(state.savingQuota ? 'Saving…' : 'Save limit'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (canWrite)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Add a number', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Mobile number'),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: state.adding
                            ? null
                            : () async {
                                final added = await ref
                                    .read(societyPhonesProvider.notifier)
                                    .addPhone(_phone.text);
                                if (added) _phone.clear();
                              },
                        child: Text(state.adding ? 'Adding…' : 'Add number'),
                      ),
                    ],
                  ),
                ),
              ),
            if (canWrite) const SizedBox(height: 12),
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Search by digits',
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  onPressed: () => ref.read(societyPhonesProvider.notifier).search(_search.text),
                  icon: const Icon(Icons.search),
                ),
              ),
              onSubmitted: (value) => ref.read(societyPhonesProvider.notifier).search(value),
            ),
            const SizedBox(height: 12),
            if (!state.loading && state.items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No society numbers yet.', style: TextStyle(color: AdminColors.muted)),
              ),
            if (state.total > state.items.length)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Showing ${state.items.length} of ${state.total}. Search to narrow the list.',
                  style: const TextStyle(color: AdminColors.muted),
                ),
              ),
            ...state.items.map(
              (item) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(item.phone),
                  trailing: canWrite
                      ? IconButton(
                          tooltip: 'Remove',
                          onPressed: state.removingId == null
                              ? () => _confirmRemove(item)
                              : null,
                          icon: state.removingId == item.id
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.delete_outline),
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(SocietyPhone item) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove number'),
        content: Text('Remove ${item.phone} from the society list?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (remove != true || !mounted) return;
    await ref.read(societyPhonesProvider.notifier).removePhone(item.id);
  }
}
