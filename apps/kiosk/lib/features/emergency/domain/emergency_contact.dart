class EmergencyContact {
  const EmergencyContact({
    required this.name,
    required this.phone,
    required this.icon,
    this.id,
    this.sortOrder,
  });

  final String? id;
  final String name;
  final String phone;
  final String icon;
  final int? sortOrder;

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      icon: json['icon'] as String? ?? 'sos',
      sortOrder: (json['sortOrder'] as num?)?.toInt(),
    );
  }
}

/// Offline / API-failure fallback — Lucknow NIC helpline set.
const List<EmergencyContact> kEmergencyContacts = [
  EmergencyContact(name: 'Police', phone: '112', icon: 'police'),
  EmergencyContact(name: 'Fire', phone: '101', icon: 'fire'),
  EmergencyContact(name: 'Ambulance', phone: '102', icon: 'ambulance'),
  EmergencyContact(name: 'Ambulance (108)', phone: '108', icon: 'ambulance'),
  EmergencyContact(name: 'Women Helpline', phone: '1090', icon: 'women'),
  EmergencyContact(name: 'Citizen Call Center', phone: '155300', icon: 'phone'),
  EmergencyContact(name: 'Child Helpline', phone: '1098', icon: 'child'),
  EmergencyContact(
    name: 'Chief Minister Helpline',
    phone: '1076',
    icon: 'sos',
  ),
  EmergencyContact(
    name: 'UP Women Commission Helpline',
    phone: '1800-180-5220',
    icon: 'women',
  ),
  EmergencyContact(
    name: 'DDMA Emergency Operations Center',
    phone: '1077',
    icon: 'disaster',
  ),
];
