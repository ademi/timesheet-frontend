import 'package:get_storage/get_storage.dart';

import '../constants/feature_flags.dart';
import 'token_storage.dart';

/// One-shot DOMAIN_V2 cutover: wipe legacy session keys so users re-login.
abstract final class DomainV2Cutover {
  DomainV2Cutover._();

  static const _flagKey = 'domain_v2_cutover_done';
  static const payrollSettingsKey = 'payroll_settings';

  /// Returns true if a wipe ran (caller should force login / show banner).
  static Future<bool> runIfNeeded(TokenStorage tokenStorage) async {
    if (!FeatureFlags.domainV2) return false;

    final box = GetStorage();
    if (box.read<bool>(_flagKey) == true) return false;

    await tokenStorage.clear();
    await box.remove(payrollSettingsKey);
    await box.write(_flagKey, true);
    return true;
  }
}
