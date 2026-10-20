import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/routes/middlewares/auth_route_utils.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../compliance_ops/data/models/compliance_ops_models.dart';
import '../../compliance_ops/data/repositories/compliance_ops_repository.dart';
import '../data/staff_preset_catalog.dart';
import 'staff_tenant_settings_controller.dart';

/// Edit staff preset / active flag via `PATCH /v1/tenant-members/{id}`.
class StaffDetailController extends GetxController {
  StaffDetailController({
    required ComplianceOpsRepository complianceOps,
    required SessionService session,
  }) : _complianceOps = complianceOps,
       _session = session;

  final ComplianceOpsRepository _complianceOps;
  final SessionService _session;

  final isLoading = false.obs;
  final isSaving = false.obs;
  final isLoadingRoles = false.obs;
  final errorMessage = RxnString();
  final member = Rxn<TenantMemberOut>();
  final roles = <AssignableStaffRoleOut>[].obs;
  final selectedPresetKey = ''.obs;
  final isActive = true.obs;

  bool get canManageStaff =>
      _session.hasPermission(AppPermissions.tenantMembersManage);

  bool get canAssignAdmin =>
      _session.hasPermission(AppPermissions.rbacManage);

  bool get isSelf {
    final id = member.value?.id;
    final mine = _session.tenantMemberId.value;
    if (id == null || id.isEmpty || mine == null || mine.isEmpty) return false;
    return id == mine;
  }

  bool get canEditRoleAndStatus => canManageStaff && !isSelf;

  List<AssignableStaffRoleOut> get pickerRoles {
    final filtered =
        roles
            .where((r) => kStaffPresetKeysAll.contains(r.key))
            .where((r) => canAssignAdmin || r.key != 'admin')
            .toList();
    filtered.sort((a, b) => staffPresetPickerCompare(a.key, b.key));
    return filtered;
  }

  bool get hasUnsavedChanges {
    final m = member.value;
    if (m == null) return false;
    final currentKey = (m.roleKey ?? '').trim().toLowerCase();
    final selected = selectedPresetKey.value.trim().toLowerCase();
    return selected != currentKey || isActive.value != m.isActive;
  }

  @override
  void onInit() {
    super.onInit();
    // ignore: discarded_futures
    hydrate();
  }

  Future<void> hydrate() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      await Future.wait([_loadMember(), loadRoles()]);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadMember() async {
    final id = (routeParam('id') ?? '').trim();
    final args = routeArguments();
    if (args is TenantMemberOut && (id.isEmpty || args.id == id)) {
      _applyMember(args);
      return;
    }
    if (id.isEmpty) {
      errorMessage.value = 'Missing staff id.';
      return;
    }
    try {
      final list = await _complianceOps.listTenantMembers();
      final found = list.where((m) => m.id == id).firstOrNull;
      if (found == null) {
        errorMessage.value = 'Staff member not found.';
        return;
      }
      _applyMember(found);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    }
  }

  void _applyMember(TenantMemberOut m) {
    member.value = m;
    final key = (m.roleKey ?? '').trim().toLowerCase();
    selectedPresetKey.value =
        kStaffPresetKeysAll.contains(key) ? key : kStaffPresetDefaultKey;
    isActive.value = m.isActive;
  }

  Future<void> loadRoles() async {
    isLoadingRoles.value = true;
    try {
      final list = await _complianceOps.listAssignableStaffRoles();
      roles.assignAll(list);
      _ensureValidSelection();
    } on AppFailure catch (_) {
      roles.assignAll([
        for (final key in kStaffPresetPickerOrder)
          if (kStaffPresetCatalog.containsKey(key))
            AssignableStaffRoleOut(
              id: key,
              key: key,
              displayName: kStaffPresetCatalog[key]!.displayName,
            ),
      ]);
      _ensureValidSelection();
    } finally {
      isLoadingRoles.value = false;
    }
  }

  void _ensureValidSelection() {
    final keys = pickerRoles.map((r) => r.key).toSet();
    if (keys.contains(selectedPresetKey.value)) return;
    if (keys.contains(kStaffPresetDefaultKey)) {
      selectedPresetKey.value = kStaffPresetDefaultKey;
    } else if (keys.isNotEmpty) {
      selectedPresetKey.value = keys.first;
    }
  }

  void selectPreset(String key) {
    if (!canEditRoleAndStatus) return;
    selectedPresetKey.value = key;
  }

  void setActive(bool value) {
    if (!canEditRoleAndStatus) return;
    isActive.value = value;
  }

  Future<void> save() async {
    final m = member.value;
    if (m == null) return;
    if (!canManageStaff) {
      errorMessage.value = 'You don’t have permission to edit staff.';
      return;
    }
    if (isSelf) {
      errorMessage.value = 'You can’t change your own role or status.';
      return;
    }
    if (!hasUnsavedChanges) {
      AppToast.success('No changes', 'Nothing to save.');
      return;
    }
    final key = selectedPresetKey.value;
    if (key == 'admin' && !canAssignAdmin) {
      errorMessage.value = 'Only an owner can assign the Admin job title.';
      return;
    }

    final deactivating = m.isActive && !isActive.value;
    if (deactivating) {
      final confirmed = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('Deactivate staff?'),
          content: Text(
            '${m.fullName ?? m.email} will not be able to log in until '
            'reactivated.',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Get.back(result: true),
              child: const Text('Deactivate'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    isSaving.value = true;
    errorMessage.value = null;
    try {
      final updated = await _complianceOps.patchTenantMember(
        m.id,
        TenantMemberPatchBody(
          presetKey: key,
          isActive: isActive.value,
        ),
      );
      // Prefer PATCH body fields if response omits role_key / is_active.
      member.value = updated.copyWith(
        roleKey: updated.roleKey ?? key,
        role:
            updated.role ??
            staffPresetDisplayName(key, fallback: updated.roleLabel),
        isActive: updated.isActive,
      );
      selectedPresetKey.value =
          (member.value!.roleKey ?? key).trim().toLowerCase();
      isActive.value = member.value!.isActive;
      AppToast.success('Saved', 'Staff member updated.');
      if (Get.isRegistered<StaffTenantSettingsController>()) {
        // ignore: discarded_futures
        Get.find<StaffTenantSettingsController>().load();
      }
    } on AppFailure catch (e) {
      errorMessage.value = _friendlyPatchError(e);
    } finally {
      isSaving.value = false;
    }
  }

  String _friendlyPatchError(AppFailure e) {
    final detail = e.message.toLowerCase();
    if (e.isAccessDenied) {
      if (detail.contains('own') || detail.contains('yourself')) {
        return 'You can’t change your own role or status.';
      }
      return 'You don’t have access to change this staff member.';
    }
    return e.message;
  }
}
