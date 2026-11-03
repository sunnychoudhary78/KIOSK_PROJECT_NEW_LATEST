class AstrologyBirthSubject {
  const AstrologyBirthSubject({
    required this.name,
    required this.gender,
    required this.dateOfBirth,
    required this.birthTime,
    required this.birthPlace,
    required this.birthTimeUnknown,
  });

  final String name;
  final String gender;
  final String dateOfBirth;
  final String birthTime;
  final String birthPlace;
  final bool birthTimeUnknown;

  Map<String, dynamic> toJson() => {
        'name': name,
        'gender': gender,
        'dateOfBirth': dateOfBirth,
        'birthTime': birthTime,
        'birthPlace': birthPlace,
        'birthTimeUnknown': birthTimeUnknown,
      };
}
