import 'package:flutter/material.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';

class LocalServiceContact {
  const LocalServiceContact({
    this.id = '',
    required this.name,
    required this.phone,
    this.rating = 0,
    this.topRank,
    this.pinned = false,
    this.address,
    this.distanceKm,
    this.photoUrl,
  });

  final String id;
  final String name;
  final String phone;
  final double rating;
  final int? topRank;
  final bool pinned;
  final String? address;
  final double? distanceKm;
  final String? photoUrl;

  factory LocalServiceContact.fromJson(Map<String, dynamic> json) {
    final ratingRaw = json['rating'];
    final rating = ratingRaw is num
        ? ratingRaw.toDouble()
        : double.tryParse(ratingRaw?.toString() ?? '') ?? 0;
    final topRankRaw = json['topRank'];
    final topRank = topRankRaw is num
        ? topRankRaw.toInt()
        : int.tryParse(topRankRaw?.toString() ?? '');
    final distanceRaw = json['distanceKm'];
    final distanceKm = distanceRaw is num
        ? distanceRaw.toDouble()
        : double.tryParse(distanceRaw?.toString() ?? '');
    return LocalServiceContact(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      rating: rating.clamp(0, 5),
      topRank: topRank != null && topRank >= 1 && topRank <= 5 ? topRank : null,
      pinned: json['pinned'] == true || topRank != null,
      address: json['address']?.toString(),
      distanceKm: distanceKm,
      photoUrl: json['photoUrl']?.toString(),
    );
  }

  String get displayPhone {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    if (digits.length == 12 && digits.startsWith('91')) {
      return '+91 ${digits.substring(2, 7)} ${digits.substring(7)}';
    }
    return phone;
  }

  /// Digits suitable for `tel:` URIs.
  String get dialDigits {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+91$digits';
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    return digits.isEmpty ? phone : digits;
  }
}

class LocalServiceCategory {
  const LocalServiceCategory({
    required this.id,
    required this.slug,
    required this.name,
    required this.contacts,
    this.isActive = true,
  });

  final String id;
  final String slug;
  final String name;
  final List<LocalServiceContact> contacts;
  final bool isActive;

  factory LocalServiceCategory.fromJson(Map<String, dynamic> json) {
    final raw = json['contacts'];
    final contacts = <LocalServiceContact>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          contacts.add(
            LocalServiceContact.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    // Defensive client sort: Top 5 → distance → rating → name.
    contacts.sort((a, b) {
      final ra = a.topRank ?? 1 << 30;
      final rb = b.topRank ?? 1 << 30;
      if (ra != rb) return ra.compareTo(rb);
      final da = a.distanceKm ?? double.infinity;
      final db = b.distanceKm ?? double.infinity;
      final byDistance = da.compareTo(db);
      if (byDistance != 0) return byDistance;
      final byRating = b.rating.compareTo(a.rating);
      if (byRating != 0) return byRating;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return LocalServiceCategory(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      contacts: contacts,
      isActive: json['isActive'] != false,
    );
  }

  IconData get icon => localServiceIconFor(slug);

  Color get accent => localServiceAccentFor(slug);
}

IconData localServiceIconFor(String slug) {
  switch (slug) {
    case 'appliance-repair':
      return Icons.kitchen_outlined;
    case 'scrap-dealer':
      return Icons.recycling_outlined;
    case 'two-wheeler-mechanic':
      return Icons.two_wheeler_outlined;
    case 'tailor':
      return Icons.content_cut_outlined;
    case 'carpenter':
      return Icons.carpenter_outlined;
    case 'gas-stove-repair':
    case 'gas-stove-repair-2':
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
      return Icons.weekend_outlined;
    case 'car-mechanic':
      return Icons.directions_car_outlined;
    case 'key-maker':
      return Icons.key_outlined;
    case 'fabricator':
      return Icons.construction_outlined;
    case 'plumber':
      return Icons.plumbing_outlined;
    case 'tempo-driver':
    case 'tempodriver':
    case 'tempo&driver':
      return Icons.local_shipping_outlined;
    default:
      if (slug.contains('tempo') || slug.contains('driver')) {
        return Icons.local_shipping_outlined;
      }
      if (slug.contains('gas')) {
        return Icons.local_fire_department_outlined;
      }
      return Icons.handyman_outlined;
  }
}

Color localServiceAccentFor(String slug) {
  switch (slug) {
    case 'appliance-repair':
      return const Color(0xFF0288D1);
    case 'scrap-dealer':
      return const Color(0xFF2E7D32);
    case 'two-wheeler-mechanic':
      return const Color(0xFF6A1B9A);
    case 'tailor':
      return const Color(0xFFC2185B);
    case 'carpenter':
      return const Color(0xFFE65100);
    case 'gas-stove-repair':
    case 'gas-stove-repair-2':
      return const Color(0xFF00838F);
    case 'electrician':
      return const Color(0xFFF57F17);
    case 'pigeon-net':
      return const Color(0xFF283593);
    case 'puncture':
      return const Color(0xFF37474F);
    case 'painter':
      return const Color(0xFFAD1457);
    case 'mason':
      return const Color(0xFFD84315);
    case 'interior':
      return const Color(0xFF00695C);
    case 'car-mechanic':
      return const Color(0xFF1565C0);
    case 'key-maker':
      return const Color(0xFFB08900);
    case 'fabricator':
      return const Color(0xFF1A237E);
    case 'plumber':
      return const Color(0xFF0091EA);
    case 'tempo-driver':
    case 'tempodriver':
    case 'tempo&driver':
      return const Color(0xFF455A64);
    default:
      if (slug.contains('tempo') || slug.contains('driver')) {
        return const Color(0xFF455A64);
      }
      if (slug.contains('gas')) {
        return const Color(0xFF00838F);
      }
      return SkpColors.accent;
  }
}
