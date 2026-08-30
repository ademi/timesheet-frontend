/// Australian Business Number helpers (11-digit ABR checksum).
abstract final class AbnUtils {
  AbnUtils._();

  static const _weights = [10, 1, 3, 5, 7, 9, 11, 13, 15, 17, 19];

  /// Digits only, or empty if [raw] has no digits.
  static String digitsOnly(String? raw) =>
      (raw ?? '').replaceAll(RegExp(r'\D'), '');

  /// Returns normalized 11-digit ABN, or null if blank.
  /// Throws [FormatException] when present but invalid.
  static String? normalizeOrNull(String? raw) {
    final digits = digitsOnly(raw);
    if (digits.isEmpty) return null;
    if (digits.length != 11) {
      throw const FormatException('ABN must be 11 digits');
    }
    final nums = digits.split('').map(int.parse).toList();
    nums[0] -= 1;
    var total = 0;
    for (var i = 0; i < 11; i++) {
      total += _weights[i] * nums[i];
    }
    if (total % 89 != 0) {
      throw const FormatException('Invalid ABN checksum');
    }
    return digits;
  }

  static String? formValidator(String? value, {bool required = false}) {
    final digits = digitsOnly(value);
    if (digits.isEmpty) {
      return required ? 'ABN is required' : null;
    }
    try {
      normalizeOrNull(digits);
      return null;
    } on FormatException catch (e) {
      return e.message;
    }
  }

  static String? bsbValidator(String? value, {bool required = false}) {
    final digits = digitsOnly(value);
    if (digits.isEmpty) {
      return required ? 'BSB is required' : null;
    }
    if (digits.length != 6) return 'BSB must be 6 digits';
    return null;
  }

  static String? accountNumberValidator(String? value, {bool required = false}) {
    final digits = digitsOnly(value);
    if (digits.isEmpty) {
      return required ? 'Account number is required' : null;
    }
    if (digits.length < 6 || digits.length > 10) {
      return 'Account number must be 6–10 digits';
    }
    return null;
  }
}
