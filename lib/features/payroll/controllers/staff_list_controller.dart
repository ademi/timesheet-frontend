import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/routes/app_navigator.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/utils/name_sort.dart';
import '../../compliance_ops/data/models/compliance_ops_models.dart';
import '../../compliance_ops/data/repositories/compliance_ops_repository.dart';
import '../data/staff_preset_catalog.dart';

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

  /// `null` = All; otherwise a normalized job-title / role key.
  final roleFilter = RxnString();

  bool get canViewStaff =>
      _session.hasPermission(AppPermissions.tenantMembersRead) ||
      _session.hasPermission(AppPermissions.tenantMembersManage);

  bool get canManageStaff =>
      _session.hasPermission(AppPermissions.tenantMembersManage);

  /// Distinct job-title keys present among current members (for filter tabs).
  List<String> get availableRoleKeys {
    final keys = <String>{};
    for (final m in members) {
      final key = memberRoleKey(m);
      if (key.isNotEmpty) keys.add(key);
    }
    final list = keys.toList()..sort(staffPresetPickerCompare);
    return list;
  }

  List<TenantMemberOut> get filtered {
    final f = roleFilter.value;
    var list = members.toList();
    if (f != null && f.isNotEmpty) {
      list = list.where((m) => memberRoleKey(m) == f).toList();
    }
    list.sort(
      (a, b) => compareNames(a.fullName ?? a.email, b.fullName ?? b.email),
    );
    return list;
  }

  static String memberRoleKey(TenantMemberOut m) {
    final normalized =
        normalizeStaffPresetKey(m.roleKey) ?? normalizeStaffPresetKey(m.role);
    if (normalized != null) return normalized;
    final key = m.roleKey?.trim().toLowerCase();
    if (key != null && key.isNotEmpty) return key;
    return m.roleLabel.trim().toLowerCase();
  }

  String roleTabLabel(String key) =>
      staffPresetDisplayName(key, fallback: key);

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
      final selected = roleFilter.value;
      if (selected != null && !availableRoleKeys.contains(selected)) {
        roleFilter.value = null;
      }
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
