import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../visits/data/models/visit_models.dart';
import '../../visits/data/repositories/visits_repository.dart';
import '../data/models/payroll_models.dart';
import '../data/repositories/payroll_repository.dart';

class StaffPaymentsController extends GetxController {
  StaffPaymentsController({
    required PayrollRepository payroll,
    required VisitsRepository visits,
    required SessionService session,
  })  : _payroll = payroll,
        _visits = visits,
        _session = session;

  final PayrollRepository _payroll;
  final VisitsRepository _visits;
  final SessionService _session;

  final tabIndex = 0.obs;
  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();

  final batches = <PaymentBatchOut>[].obs;
  final selectedBatch = Rxn<PaymentBatchOut>();
  final batchStatusFilter = ''.obs;

  final unpaidVisits = <VisitOut>[].obs;
  final selectedVisitIds = <String>{}.obs;

  final periodLabelCtrl = TextEditingController();

  bool get canView =>
      _session.hasPermission(AppPermissions.paymentsView) ||
      _session.hasPermission(AppPermissions.paymentsManage);
  bool get canManage =>
      _session.hasPermission(AppPermissions.paymentsManage);

  @override
  void onInit() {
    super.onInit();
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    periodLabelCtrl.text = '$today..$today';
    loadAll();
  }

  @override
  void onClose() {
    periodLabelCtrl.dispose();
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
}
