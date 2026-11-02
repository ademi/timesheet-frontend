import 'package:get/get.dart';

import '../../../../app/constants/app_permissions.dart';
import '../../../../core/services/session_service.dart';

/// FE-0 shell: route + permission gate. Connect/status UI lands in FE-1.
class XeroSettingsController extends GetxController {
  XeroSettingsController({required SessionService session}) : _session = session;

  final SessionService _session;

  bool get canManageXero =>
      _session.hasPermission(AppPermissions.integrationsXeroManage);

  void onScreenReenter() {}
}
