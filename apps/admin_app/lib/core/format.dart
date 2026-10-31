String formatTimestamp(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

String formatRupees(int amountPaise) {
  final rupees = amountPaise / 100;
  if (amountPaise % 100 == 0) return '₹${rupees.toStringAsFixed(0)}';
  return '₹${rupees.toStringAsFixed(2)}';
}

String statusLabel(String status) {
  if (status.isEmpty) return '—';
  return status
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String printSourceLabel(String source) {
  return switch (source) {
    'otp_print' => 'OTP print',
    'quick_print' => 'Quick print',
    'digilocker_print' => 'DigiLocker',
    _ => statusLabel(source),
  };
}
