import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../compliance_ops/data/models/compliance_ops_models.dart';
import '../../compliance_ops/data/repositories/compliance_ops_repository.dart';
import '../../subscription/billing_gate.dart';
import '../data/models/payroll_models.dart';
import '../data/repositories/payroll_repository.dart';

class StaffTenantSettingsController extends GetxController {
  StaffTenantSettingsController({
    required PayrollRepository payroll,
    required ComplianceOpsRepository complianceOps,
    required SessionService session,
  })  : _payroll = payroll,
        _complianceOps = complianceOps,
        _session = session;

  final PayrollRepository _payroll;
  final ComplianceOpsRepository _complianceOps;
  final SessionService _session;

  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();
  final tenant = Rxn<TenantSettingsOut>();
  final subscription = Rxn<SubscriptionStatusOut>();
  final members = <TenantMemberOut>[].obs;

  final timezoneCtrl = TextEditingController();
  final jurisdictionCtrl = TextEditingController();

  bool get canManage =>
      _session.hasPermission(AppPermissions.tenantsManage);
  bool get canViewMembers =>
      _session.hasPermission(AppPermissions.tenantMembersRead) ||
      _session.hasPermission(AppPermissions.tenantMembersManage);
  bool get canViewBilling =>
      _session.hasPermission(AppPermissions.subscriptionView) ||
      _session.hasPermission(AppPermissions.billingView) ||
      canManage;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    timezoneCtrl.dispose();
    jurisdictionCtrl.dispose();
    super.onClose();
  }

  Future<void> load() async {
    final id = _session.tenantId.value;
    if (id == null || id.isEmpty) {
      errorMessage.value = 'No tenant in session.';
      return;
    }
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final t = await _payroll.getTenant(id);
      tenant.value = t;
      timezoneCtrl.text = t.timezone ?? '';
      jurisdictionCtrl.text = t.publicHolidayJurisdiction ?? '';
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    }
    if (canViewBilling) {
      try {
        subscription.value = await _complianceOps.getSubscription();
      } on AppFailure catch (_) {}
    }
    if (canViewMembers) {
      try {
        members.assignAll(await _complianceOps.listTenantMembers());
      } on AppFailure catch (_) {}
    }
    isLoading.value = false;
  }

  Future<void> save() async {
    if (!canManage) {
      errorMessage.value = 'Missing tenants.manage permission.';
      return;
    }
    final id = _session.tenantId.value;
    if (id == null) return;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final updated = await _payroll.patchTenant(
        id,
        timezone: timezoneCtrl.text.trim().isEmpty
            ? null
            : timezoneCtrl.text.trim(),
        publicHolidayJurisdiction: jurisdictionCtrl.text.trim().isEmpty
            ? null
            : jurisdictionCtrl.text.trim(),
      );
      tenant.value = updated;
      AppToast.success(
        'Saved',
        'Tenant timezone / holiday jurisdiction updated.',
      );
    } on AppFailure catch (e) {
      await BillingGate.showIfNeeded(e);
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> openBilling() => BillingGate.openBillingUrl();
}
