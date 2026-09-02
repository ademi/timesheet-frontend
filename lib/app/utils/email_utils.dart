/// Email normalization and validation (mirrors backend `app.core.email_utils`).
abstract final class EmailUtils {
  EmailUtils._();

  static const String formatHint = 'Enter a valid email';

  static final RegExp _emailPattern = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static String normalize(String value) => value.trim().toLowerCase();

  static bool isValid(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    return _emailPattern.hasMatch(trimmed);
  }

  static String? validationError(String? value, {bool required = true}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return required ? formatHint : null;
    }
    if (!isValid(trimmed)) {
      return formatHint;
    }
    return null;
  }
}
