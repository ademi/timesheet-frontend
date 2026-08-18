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

class ContractorBatchCandidate {
  const ContractorBatchCandidate({
    required this.contractorId,
    required this.contractorName,
    required this.visits,
    required this.totalHours,
    required this.firstVisitAt,
    required this.lastVisitAt,
  });

  final String contractorId;
  final String contractorName;
  final List<VisitOut> visits;
  final double totalHours;
  final DateTime firstVisitAt;
  final DateTime lastVisitAt;

  int get visitCount => visits.length;
  List<String> get visitIds => visits.map((visit) => visit.id).toList(growable: false);
}

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
  final selectedContractorIds = <String>{}.obs;

  final periodLabelCtrl = TextEditingController();
  final contractorFilterCtrl = TextEditingController();
  final contractorFilter = ''.obs;

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
    contractorFilterCtrl.addListener(() {
      contractorFilter.value = contractorFilterCtrl.text.trim();
    });
    loadAll();
  }

  @override
  void onClose() {
    periodLabelCtrl.dispose();
    contractorFilterCtrl.dispose();
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

  List<ContractorBatchCandidate> get contractorCandidates {
    final grouped = <String, List<VisitOut>>{};
    for (final visit in unpaidVisits) {
      grouped.putIfAbsent(visit.contractorId, () => <VisitOut>[]).add(visit);
    }

    final result = grouped.entries.map((entry) {
      final visits = [...entry.value]
        ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
      final firstVisitAt = visits.first.scheduledStart;
      final lastVisitAt = visits.last.scheduledEnd;
      final totalHours = visits.fold<double>(0, (sum, visit) {
        final hours = visit.scheduledEnd.difference(visit.scheduledStart).inMinutes / 60;
        return sum + hours;
      });

      return ContractorBatchCandidate(
        contractorId: entry.key,
        contractorName: visits.first.contractorName?.trim().isNotEmpty == true
            ? visits.first.contractorName!.trim()
            : entry.key,
        visits: visits,
        totalHours: totalHours,
        firstVisitAt: firstVisitAt,
        lastVisitAt: lastVisitAt,
      );
    }).toList()
      ..sort((a, b) => a.contractorName.toLowerCase().compareTo(b.contractorName.toLowerCase()));

    return result;
  }

  List<ContractorBatchCandidate> get filteredContractorCandidates {
    final query = contractorFilter.value.trim().toLowerCase();
    if (query.isEmpty) return contractorCandidates;

    return contractorCandidates.where((candidate) {
      return candidate.contractorName.toLowerCase().contains(query) ||
          candidate.contractorId.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  int get selectedVisitCount {
    var count = 0;
    for (final candidate in contractorCandidates) {
      if (selectedContractorIds.contains(candidate.contractorId)) {
        count += candidate.visitCount;
      }
    }
    return count;
  }

  double get selectedTotalHours {
    var total = 0.0;
    for (final candidate in contractorCandidates) {
      if (selectedContractorIds.contains(candidate.contractorId)) {
        total += candidate.totalHours;
      }
    }
    return total;
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

  void toggleContractor(String contractorId) {
    if (selectedContractorIds.contains(contractorId)) {
      selectedContractorIds.remove(contractorId);
    } else {
      selectedContractorIds.add(contractorId);
    }
  }

  Future<void> createBatch() async {
    if (!canManage) return;
    final visitIds = <String>[];
    for (final candidate in contractorCandidates) {
      if (selectedContractorIds.contains(candidate.contractorId)) {
        visitIds.addAll(candidate.visitIds);
      }
    }

    if (visitIds.isEmpty) {
      errorMessage.value = 'Select at least one contractor to include in the batch.';
      return;
    }
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final key =
          'fe-batch-${DateTime.now().toUtc().microsecondsSinceEpoch}';
      final created = await _payroll.createBatch(
        PaymentBatchCreateRequest(
          visitIds: visitIds,
          periodLabel: periodLabelCtrl.text.trim(),
        ),
        idempotencyKey: key,
      );
      selectedBatch.value = created;
      selectedContractorIds.clear();
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
