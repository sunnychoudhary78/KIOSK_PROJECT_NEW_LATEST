import 'package:flutter/material.dart';
import 'package:skp_admin/features/cabinet_light/presentation/cabinet_light_page.dart';
import 'package:skp_admin/features/society_phones/presentation/society_phones_page.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.phone_outlined),
              title: const Text('Society phones'),
              subtitle: const Text('Free-page limit and listed numbers'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SocietyPhonesPage()),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lightbulb_outline),
              title: const Text('Cabinet light'),
              subtitle: const Text('On, off, or a daily schedule'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CabinetLightPage()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
