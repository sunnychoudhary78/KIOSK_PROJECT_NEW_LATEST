class EmergencyContact {
  const EmergencyContact({
    required this.name,
    required this.phone,
    required this.icon,
  });

  final String name;
  final String phone;
  final String icon;
}

/// Fixed India national emergency numbers (display-only on kiosk).
const List<EmergencyContact> kEmergencyContacts = [
  EmergencyContact(
    name: 'National Emergency',
    phone: '112',
    icon: 'sos',
  ),
  EmergencyContact(
    name: 'Police',
    phone: '100',
    icon: 'police',
  ),
  EmergencyContact(
    name: 'Fire',
    phone: '101',
    icon: 'fire',
  ),
  EmergencyContact(
    name: 'Ambulance',
    phone: '102',
    icon: 'ambulance',
  ),
  EmergencyContact(
    name: 'Ambulance (108)',
    phone: '108',
    icon: 'ambulance',
  ),
  EmergencyContact(
    name: 'Women Helpline',
    phone: '1091',
    icon: 'women',
  ),
  EmergencyContact(
    name: 'Child Helpline',
    phone: '1098',
    icon: 'child',
  ),
  EmergencyContact(
    name: 'Disaster Management',
    phone: '1078',
    icon: 'disaster',
  ),
];
