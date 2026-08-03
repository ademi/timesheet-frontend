import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../engagements/data/models/engagement_models.dart';
import '../../engagements/data/repositories/engagements_repository.dart';
import '../../visits/data/models/visit_models.dart';
import '../../visits/data/repositories/visits_repository.dart';
import '../data/models/payroll_models.dart';
import '../data/repositories/payroll_repository.dart';

class StaffPaymentsController extends GetxController {
  StaffPaymentsController({
    required PayrollRepository payroll,
    required EngagementsRepository engagements,
    required VisitsRepository visits,
    required SessionService session,
  })  : _payroll = payroll,
        _engagements = engagements,
        _visits = visits,
        _session = session;

  final PayrollRepository _payroll;
  final EngagementsRepository _engagements;
  final VisitsRepository _visits;
  final SessionService _session;

  final tabIndex = 0.obs;
  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();

  final batches = <PaymentBatchOut>[].obs;
  final selectedBatch = Rxn<PaymentBatchOut>();
  final batchStatusFilter = ''.obs;

  final engagements = <EngagementOut>[].obs;
  final selectedEngagementId = RxnString();
  final rates = <EngagementRateOut>[].obs;

  final unpaidVisits = <VisitOut>[].obs;
  final selectedVisitIds = <String>{}.obs;

  final periodLabelCtrl = TextEditingController();
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
    periodLabelCtrl.text =
        '${effectiveFromCtrl.text}..${effectiveFromCtrl.text}';
    loadAll();
  }

  @override
  void onClose() {
    periodLabelCtrl.dispose();
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

  Future<void> loadAll() async {
    if (!canView) {
      errorMessage.value = 'Missing payments.view permission.';
      return;
    }
    isLoading.value = true;
    errorMessage.value = null;
    try {
      await _loadBatches();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    }
    try {
      engagements.assignAll(await _engagements.listTenantEngagements());
    } on AppFailure catch (e) {
      errorMessage.value ??= e.message;
    }
    try {
      await _loadUnpaidVisits();
    } on AppFailure catch (e) {
      errorMessage.value ??= e.message;
    }
    isLoading.value = false;
  }

  Future<void> _loadBatches() async {
    final status = batchStatusFilter.value.trim();
    batches.assignAll(
      await _payroll.listBatches(status: status.isEmpty ? null : status),
    );
  }

  Future<void> _loadUnpaidVisits() async {
    final now = DateTime.now().toUtc();
    final from = now.subtract(const Duration(days: 90));
    final list = await _visits.listVisits(
      from: from,
      to: now.add(const Duration(days: 1)),
      status: 'completed',
      paymentStatus: 'unpaid',
    );
    unpaidVisits.assignAll(list);
  }

  Future<void> setBatchStatusFilter(String? status) async {
    batchStatusFilter.value = status ?? '';
    isLoading.value = true;
    errorMessage.value = null;
    try {
      await _loadBatches();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadRatesFor(String? engagementId) async {
    selectedEngagementId.value = engagementId;
    rates.clear();
    if (engagementId == null) return;
    isLoading.value = true;
    errorMessage.value = null;
    try {
      rates.assignAll(await _payroll.listRates(engagementId));
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  void toggleVisit(String id) {
    if (selectedVisitIds.contains(id)) {
      selectedVisitIds.remove(id);
    } else {
      selectedVisitIds.add(id);
    }
  }

  Future<void> createBatch() async {
    if (!canManage) return;
    if (selectedVisitIds.isEmpty) {
      errorMessage.value = 'Select at least one unpaid completed visit.';
      return;
    }
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final key =
          'fe-batch-${DateTime.now().toUtc().microsecondsSinceEpoch}';
      final created = await _payroll.createBatch(
        PaymentBatchCreateRequest(
          visitIds: selectedVisitIds.toList(),
          periodLabel: periodLabelCtrl.text.trim(),
        ),
        idempotencyKey: key,
      );
      selectedBatch.value = created;
      selectedVisitIds.clear();
      await _loadBatches();
      await _loadUnpaidVisits();
      Get.snackbar(
        'Batch created',
        'Draft ${created.id} · ${created.totalAmount} ${created.currencyCode}',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: AppColors.primary,
        colorText: AppColors.onPrimary,
      );
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> postBatch(PaymentBatchOut batch) async {
    if (!canManage) return;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final updated = await _payroll.postBatch(batch.id);
      selectedBatch.value = updated;
      await _loadBatches();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> voidBatch(PaymentBatchOut batch) async {
    if (!canManage) return;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final updated = await _payroll.voidBatch(batch.id);
      selectedBatch.value = updated;
      await _loadBatches();
      await _loadUnpaidVisits();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  void openBatch(PaymentBatchOut batch) {
    selectedBatch.value = batch;
  }

  Future<void> createRate() async {
    final engagementId = selectedEngagementId.value;
    if (!canManage || engagementId == null) return;
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
        engagementId,
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
      await loadRatesFor(engagementId);
      Get.snackbar(
        'Rate saved',
        'New rate card applied (prior open rates end automatically).',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }
}
