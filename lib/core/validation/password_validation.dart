/// Shared password rules for first-login and change-password flows.
class PasswordValidation {
  PasswordValidation._();

  static const int minLength = 8;

  static const Set<String> weakPasswords = {
    'password',
    'password1',
    'password12',
    'password123',
    '12345678',
    '123456789',
    '1234567890',
    'qwertyui',
    'qwerty123',
    'qwerty12',
    'letmein1',
    'welcome1',
    'changeme',
    'admin123',
    'football',
    'baseball',
    'iloveyou',
    'sunshine',
    'princess',
    'dragon12',
    'trustno1',
    'master12',
    'login123',
    'abc12345',
    'passw0rd',
    'pass1234',
    'test1234',
    'guest123',
    'default1',
    'changeme123',
    'timesheet',
    'timesheet1',
  };

  static String? validate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < minLength) {
      return 'Password must be at least $minLength characters';
    }
    if (weakPasswords.contains(value.toLowerCase())) {
      return 'Password is too common; choose a different password';
    }
    return null;
  }
}
