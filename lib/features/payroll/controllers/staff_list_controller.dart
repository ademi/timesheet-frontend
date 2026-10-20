import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/routes/app_navigator.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../compliance_ops/data/models/compliance_ops_models.dart';
import '../../compliance_ops/data/repositories/compliance_ops_repository.dart';

/// Staff directory (shell tab) — list + navigate to add/detail.
class StaffListController extends GetxController {
  StaffListController({
    required ComplianceOpsRepository complianceOps,
    required SessionService session,
  }) : _complianceOps = complianceOps,
       _session = session;

  final ComplianceOpsRepository _complianceOps;
  final SessionService _session;

  final isLoading = false.obs;
  final errorMessage = RxnString();
  final members = <TenantMemberOut>[].obs;

  bool get canViewStaff =>
      _session.hasPermission(AppPermissions.tenantMembersRead) ||
      _session.hasPermission(AppPermissions.tenantMembersManage);

  bool get canManageStaff =>
      _session.hasPermission(AppPermissions.tenantMembersManage);

  @override
  void onInit() {
    super.onInit();
    // ignore: discarded_futures
    load();
  }

  void onScreenReenter() {
    errorMessage.value = null;
    // ignore: discarded_futures
    load();
  }

  Future<void> load() async {
    if (!canViewStaff) {
      members.clear();
      errorMessage.value = 'You don’t have access to view staff.';
      return;
    }
    isLoading.value = true;
    errorMessage.value = null;
    try {
      members.assignAll(await _complianceOps.listTenantMembers());
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  void openAdd() {
    if (!canManageStaff) return;
    AppNavigator.push(AppRoutes.staffAdd);
  }

  void openDetail(TenantMemberOut m) {
    if (!canManageStaff) return;
    AppNavigator.push(
      AppNavigator.location(AppRoutes.staffDetail, query: {'id': m.id}),
      extra: m,
    );
  }
}
