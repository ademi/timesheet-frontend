import 'package:get_storage/get_storage.dart';

import '../models/payroll/payroll_settings.dart';

class PayrollSettingsStorage {
  PayrollSettingsStorage({GetStorage? storage})
    : _storage = storage ?? GetStorage();

  static const _settingsKey = 'payroll_settings';

  final GetStorage _storage;

  PayrollSettings? readSettings() {
    final value = _storage.read(_settingsKey);
    if (value is Map) {
      return PayrollSettings.fromJson(Map<String, dynamic>.from(value));
    }
    return null;
  }

  Future<void> saveSettings(PayrollSettings settings) {
    return _storage.write(_settingsKey, settings.toJson());
  }

  Future<void> clearSettings() => _storage.remove(_settingsKey);
}
