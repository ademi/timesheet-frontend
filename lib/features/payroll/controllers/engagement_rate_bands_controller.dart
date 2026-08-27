import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/models/payroll_models.dart';
import '../data/repositories/payroll_repository.dart';

class EngagementRateBandsController extends GetxController {
  EngagementRateBandsController({
    required PayrollRepository payroll,
    required SessionService session,
  })  : _payroll = payroll,
        _session = session;

  final PayrollRepository _payroll;
  final SessionService _session;

  final engagementId = RxnString();
  final rates = <EngagementRateOut>[].obs;
  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();

  final effectiveFromCtrl = TextEditingController();
  final baseRateCtrl = TextEditingController(text: '45.00');
  final eveningRateCtrl = TextEditingController();
  final nightRateCtrl = TextEditingController();
  final saturdayRateCtrl = TextEditingController();
  final sundayRateCtrl = TextEditingController();
  final phRateCtrl = TextEditingController();
  final eveningStartCtrl = TextEditingController(text: '18:00:00');
  final eveningEndCtrl = TextEditingController(text: '22:00:00');
  final nightStartCtrl = TextEditingController(text: '22:00:00');
  final nightEndCtrl = TextEditingController(text: '06:00:00');

  bool get canView =>
      _session.hasPermission(AppPermissions.paymentsView) ||
      _session.hasPermission(AppPermissions.paymentsManage);
  bool get canManage =>
      _session.hasPermission(AppPermissions.paymentsManage);

  @override
  void onInit() {
    super.onInit();
    final now = DateTime.now();
    effectiveFromCtrl.text =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void onClose() {
    effectiveFromCtrl.dispose();
    baseRateCtrl.dispose();
    eveningRateCtrl.dispose();
    nightRateCtrl.dispose();
    saturdayRateCtrl.dispose();
    sundayRateCtrl.dispose();
    phRateCtrl.dispose();
    eveningStartCtrl.dispose();
    eveningEndCtrl.dispose();
    nightStartCtrl.dispose();
    nightEndCtrl.dispose();
    super.onClose();
  }

  Future<void> loadFor(String id) async {
    if (id.isEmpty) return;
    engagementId.value = id;
    rates.clear();
    if (!canView) {
      errorMessage.value = 'Missing payments.view permission.';
      return;
    }
    isLoading.value = true;
    errorMessage.value = null;
    try {
      rates.assignAll(await _payroll.listRates(id));
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> createRate({bool popOnSuccess = false}) async {
    final id = engagementId.value;
    if (!canManage || id == null || id.isEmpty) return;
    final base = double.tryParse(baseRateCtrl.text.trim());
    if (base == null || base <= 0) {
      errorMessage.value = 'Base rate is required.';
      return;
    }
    double? opt(TextEditingController c) {
      final t = c.text.trim();
      if (t.isEmpty) return null;
      return double.tryParse(t);
    }

    isSaving.value = true;
    errorMessage.value = null;
    try {
      await _payroll.createRate(
        id,
        EngagementRateCreateRequest(
          effectiveFrom: effectiveFromCtrl.text.trim(),
          bands: RateBands(
            base: base,
            evening: opt(eveningRateCtrl),
            night: opt(nightRateCtrl),
            saturday: opt(saturdayRateCtrl),
            sunday: opt(sundayRateCtrl),
            publicHoliday: opt(phRateCtrl),
          ),
          eveningStart: eveningStartCtrl.text.trim(),
          eveningEnd: eveningEndCtrl.text.trim(),
          nightStart: nightStartCtrl.text.trim(),
          nightEnd: nightEndCtrl.text.trim(),
        ),
      );
      await loadFor(id);
      if (popOnSuccess) {
        Get.back();
      }
      AppToast.success(
        'Payment rates saved',
        'New payment rate applied (prior open rates end automatically).',
      );
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isSaving.value = false;
    }
  }
}
