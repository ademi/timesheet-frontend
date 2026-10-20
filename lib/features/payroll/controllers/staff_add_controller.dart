import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/routes/app_navigator.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../compliance_ops/data/models/compliance_ops_models.dart';
import '../../compliance_ops/data/repositories/compliance_ops_repository.dart';
import '../data/staff_preset_catalog.dart';
import 'staff_tenant_settings_controller.dart';

/// P0 Add Staff: Admin / Supervisor presets only; prefer `preset_key`.
class StaffAddController extends GetxController {
  StaffAddController({
    required ComplianceOpsRepository complianceOps,
    required SessionService session,
  }) : _complianceOps = complianceOps,
       _session = session;

  final ComplianceOpsRepository _complianceOps;
  final SessionService _session;

  final formKey = GlobalKey<FormState>();
  final fullNameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  final isLoadingRoles = false.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();
  final roles = <AssignableStaffRoleOut>[].obs;
  final selectedPresetKey = 'supervisor'.obs;

  bool get canManageStaff =>
      _session.hasPermission(AppPermissions.tenantMembersManage);

  bool get canAssignAdmin =>
      _session.hasPermission(AppPermissions.rbacManage);

  List<AssignableStaffRoleOut> get pickerRoles {
    final filtered =
        roles.where((r) => kStaffPresetKeysP0.contains(r.key)).toList();
    if (!canAssignAdmin) {
      return filtered.where((r) => r.key != 'admin').toList();
    }
    return filtered;
  }

  @override
  void onInit() {
    super.onInit();
    // ignore: discarded_futures
    loadRoles();
  }

  @override
  void onClose() {
    fullNameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    super.onClose();
  }

  Future<void> loadRoles() async {
    isLoadingRoles.value = true;
    errorMessage.value = null;
    try {
      final list = await _complianceOps.listAssignableStaffRoles();
      roles.assignAll(list);
      _ensureValidSelection();
    } on AppFailure catch (e) {
      // Fallback: catalog-only Admin/Supervisor so the form still works.
      roles.assignAll([
        const AssignableStaffRoleOut(
          id: 'admin',
          key: 'admin',
          displayName: 'Admin',
        ),
        const AssignableStaffRoleOut(
          id: 'supervisor',
          key: 'supervisor',
          displayName: 'Supervisor / Coordinator',
        ),
      ]);
      _ensureValidSelection();
      if (e.statusCode == 403 || e.code == 'forbidden') {
        errorMessage.value = 'You don’t have access to load job titles.';
      }
    } finally {
      isLoadingRoles.value = false;
    }
  }

  void _ensureValidSelection() {
    final keys = pickerRoles.map((r) => r.key).toSet();
    if (keys.contains(selectedPresetKey.value)) return;
    if (keys.contains('supervisor')) {
      selectedPresetKey.value = 'supervisor';
    } else if (keys.isNotEmpty) {
      selectedPresetKey.value = keys.first;
    }
  }

  void selectPreset(String key) {
    selectedPresetKey.value = key;
  }

  String? validateFullName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Full name is required';
    return null;
  }

  String? validateEmail(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Email is required';
    if (!GetUtils.isEmail(s)) return 'Enter a valid email';
    return null;
  }

  Future<void> submit() async {
    if (!canManageStaff) {
      errorMessage.value = 'You don’t have permission to create staff.';
      return;
    }
    if (!(formKey.currentState?.validate() ?? false)) return;
    final key = selectedPresetKey.value;
    if (key == 'admin' && !canAssignAdmin) {
      errorMessage.value =
          'Only an owner can assign the Admin job title.';
      return;
    }
    isSaving.value = true;
    errorMessage.value = null;
    final email = emailCtrl.text.trim();
    try {
      await _complianceOps.createTenantMember(
        TenantMemberCreateBody(
          fullName: fullNameCtrl.text.trim(),
          email: email,
          phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
          presetKey: key,
        ),
      );
      AppToast.success(
        'Staff invited',
        'Staff invite sent to $email. They will open the link and set '
            'their own password.',
      );
      if (Get.isRegistered<StaffTenantSettingsController>()) {
        // ignore: discarded_futures
        Get.find<StaffTenantSettingsController>().load();
      }
      AppNavigator.pop();
    } on AppFailure catch (e) {
      errorMessage.value = _friendlyCreateError(e);
    } finally {
      isSaving.value = false;
    }
  }

  String _friendlyCreateError(AppFailure e) {
    final detail = e.message.toLowerCase();
    if (e.statusCode == 403 ||
        e.code == 'forbidden' ||
        e.code == 'missing_permission') {
      return 'You don’t have access to create staff or assign that job title.';
    }
    if (e.statusCode == 409 ||
        e.code == 'conflict' ||
        detail.contains('already') ||
        detail.contains('exists')) {
      return 'A user with that email already exists.';
    }
    if (detail.contains('contractor') ||
        e.code.contains('contractor') ||
        detail.contains('hard split') ||
        detail.contains('cannot be both')) {
      return 'That email belongs to a contractor and can’t be used for staff.';
    }
    return e.message;
  }
}
