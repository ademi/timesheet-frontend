const kRequiredSlotsUiMax = 20;

int parseRequiredSlots(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return 1;
  final n = int.tryParse(digits) ?? 1;
  if (n < 1) return 1;
  if (n > kRequiredSlotsUiMax) return kRequiredSlotsUiMax;
  return n;
}
