/// Descriptor for a USB/serial port discovered on the host.
class SerialDevice {
  const SerialDevice({
    required this.name,
    this.description,
    this.transport,
    this.manufacturer,
    this.productName,
    this.serialNumber,
  });

  /// Platform port name (e.g. `COM5` on Windows).
  final String name;

  final String? description;
  final String? transport;
  final String? manufacturer;
  final String? productName;
  final String? serialNumber;

  String get displayLabel {
    final detail = description?.trim();
    if (detail != null && detail.isNotEmpty && detail != name) {
      return '$name — $detail';
    }
    return name;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SerialDevice && other.name == name;

  @override
  int get hashCode => name.hashCode;
}
