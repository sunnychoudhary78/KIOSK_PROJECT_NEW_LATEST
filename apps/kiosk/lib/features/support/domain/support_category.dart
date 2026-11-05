enum SupportCategory {
  print,
  charging,
  sensors,
  payment,
  other;

  String get apiValue => name;

  String get label => switch (this) {
        SupportCategory.print => 'Print',
        SupportCategory.charging => 'Charging',
        SupportCategory.sensors => 'Sensors',
        SupportCategory.payment => 'Payment',
        SupportCategory.other => 'Other',
      };
}
