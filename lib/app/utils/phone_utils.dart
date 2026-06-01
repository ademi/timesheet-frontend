/// E.164 phone normalization (mirrors backend `app.core.phone_utils`).
abstract final class PhoneUtils {
  PhoneUtils._();

  /// Default country code for national/local numbers (leading 0) when no + prefix.
  static const String defaultCountryCode = '61';

  static const String formatHint =
      'Use +country code (e.g. +614…, +967…) or local number with leading 0';

  static final RegExp _e164Pattern = RegExp(r'^\+[1-9]\d{7,14}$');
  static final RegExp _nonDigits = RegExp(r'\D');

  /// Returns canonical E.164 phone or `null` if blank.
  static String? tryNormalize(
    String? raw, {
    String countryCode = defaultCountryCode,
  }) {
    if (raw == null) return null;
    final text = raw.trim();
    if (text.isEmpty) return null;

    final hadPlus = text.startsWith('+');
    final digits = text.replaceAll(_nonDigits, '');
    if (digits.isEmpty) {
      throw FormatException(formatHint);
    }

    late final String normalized;
    if (hadPlus || (digits.length >= 11 && !digits.startsWith('0'))) {
      normalized = '+$digits';
    } else if (digits.startsWith('0')) {
      normalized = '+$countryCode${digits.substring(1)}';
    } else if (digits.length >= 8 &&
        digits.length <= 10 &&
        !digits.startsWith(countryCode)) {
      normalized = '+$countryCode${digits.replaceFirst(RegExp(r'^0+'), '')}';
    } else if (digits.length >= 10) {
      normalized = '+$digits';
    } else {
      throw FormatException(formatHint);
    }

    if (!_e164Pattern.hasMatch(normalized)) {
      throw FormatException(formatHint);
    }
    return normalized;
  }

  static String? validationError(String? raw) {
    try {
      tryNormalize(raw);
      return null;
    } on FormatException catch (e) {
      return e.message;
    }
  }
}
