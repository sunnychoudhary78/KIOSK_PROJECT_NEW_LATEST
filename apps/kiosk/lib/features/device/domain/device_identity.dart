/// Device identity shown after activation.
class DeviceIdentity {
  const DeviceIdentity({
    required this.deviceKey,
    this.deviceName,
  });

  final String deviceKey;
  final String? deviceName;
}
