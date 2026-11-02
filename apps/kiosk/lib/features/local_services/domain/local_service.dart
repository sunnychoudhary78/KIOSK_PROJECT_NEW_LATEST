class LocalServiceContact {
  const LocalServiceContact({required this.name, required this.phone});

  final String name;
  final String phone;

  factory LocalServiceContact.fromJson(Map<String, dynamic> json) {
    return LocalServiceContact(
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
    );
  }
}

class LocalServiceCategory {
  const LocalServiceCategory({
    required this.slug,
    required this.name,
    required this.contacts,
  });

  final String slug;
  final String name;
  final List<LocalServiceContact> contacts;

  factory LocalServiceCategory.fromJson(Map<String, dynamic> json) {
    final raw = json['contacts'];
    final contacts = <LocalServiceContact>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          contacts.add(LocalServiceContact.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return LocalServiceCategory(
      slug: json['slug']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      contacts: contacts,
    );
  }
}
