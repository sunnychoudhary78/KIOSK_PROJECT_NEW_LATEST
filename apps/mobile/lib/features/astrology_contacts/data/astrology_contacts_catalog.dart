import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:skp_mobile/features/astrology_contacts/domain/astrology_contact.dart';

/// UAT snapshot used when citizen cannot call device/admin-only list API.
abstract final class AstrologyContactsCatalog {
  static const assetPath = 'assets/astrology_contacts/catalog.json';

  static List<AstrologyContact>? _cache;

  static Future<List<AstrologyContact>> load() async {
    final cached = _cache;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const [];
    final items = decoded['items'];
    if (items is! List) return const [];

    final contacts = <AstrologyContact>[
      for (final item in items)
        if (item is Map)
          AstrologyContact.fromJson(Map<String, dynamic>.from(item)),
    ];
    contacts.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      if (byOrder != 0) return byOrder;
      return a.name.compareTo(b.name);
    });
    _cache = contacts;
    return contacts;
  }
}
