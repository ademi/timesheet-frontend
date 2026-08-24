import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../visits/data/models/visit_models.dart';
import '../../visits/data/repositories/visits_repository.dart';
import '../data/models/billing_models.dart';
import '../data/repositories/billing_repository.dart';
import '../utils/invoice_export_errors.dart';
import '../utils/visit_export_preflight.dart';

String invoiceExportStatusLabel(String status) {
  switch (status) {
    case 'finalized':
      return 'Finalized';
    case 'void':
      return 'Void';
    default:
      return status;
  }
}

class InvoiceExportsController extends GetxController {
  InvoiceExportsController({
    required BillingRepository repository,
    required VisitsRepository visitsRepository,
    required SessionService session,
  }) : _repository = repository,
       _visitsRepository = visitsRepository,
       _session = session;

  final BillingRepository _repository;
  final VisitsRepository _visitsRepository;
  final SessionService _session;

  final tabIndex = 0.obs;
  final exports = <InvoiceExportOut>[].obs;
  final exportableVisits = <VisitOut>[].obs;
  final selectedVisitIds = <String>{}.obs;
  final excludedVisitIds = <String>{}.obs;
  final lastVisitErrors = <InvoiceExportVisitError>[].obs;
  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();

  late final Rx<DateTimeRange> periodRange;

  bool get canView => _session.canViewBilling;
  bool get canManage => _session.canManageBilling;

  @override
  void onInit() {
    super.onInit();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    periodRange = DateTimeRange(
      start: today.subtract(const Duration(days: 13)),
      end: today,
    ).obs;
    loadExports();
  }

  Future<void> loadExports() async {
    if (!canView) {
      errorMessage.value = 'Missing billing.view permission.';
      return;
    }
    isLoading.value = true;
    errorMessage.value = null;
    try {
      exports.assignAll(await _repository.listInvoiceExports());
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadExportableVisits() async {
    if (!canManage) return;
    final range = periodRange.value;
    final from = DateTime.utc(range.start.year, range.start.month, range.start.day);
    final to = DateTime.utc(range.end.year, range.end.month, range.end.day)
        .add(const Duration(days: 1));
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final list = await _visitsRepository.listVisits(
        from: from,
        to: to,
        status: 'completed',
        limit: 200,
      );
      exportableVisits.assignAll(
        list.where((v) => !excludedVisitIds.contains(v.id)).toList(),
      );
      selectedVisitIds.removeWhere(
        (id) => !exportableVisits.any((v) => v.id == id),
      );
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadAll() async {
    await loadExports();
    if (canManage) {
      await loadExportableVisits();
    }
  }

  Future<void> pickPeriod(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: periodRange.value,
    );
    if (picked == null) return;
    periodRange.value = picked;
    selectedVisitIds.clear();
    lastVisitErrors.clear();
    await loadExportableVisits();
  }

  VisitExportPreflight preflightFor(VisitOut visit) =>
      buildVisitExportPreflight(visit);

  InvoiceExportVisitError? visitErrorFor(String visitId) {
    for (final err in lastVisitErrors) {
      if (err.visitId == visitId) return err;
    }
    return null;
  }

  bool get selectedVisitsReady {
    final selected = exportableVisits
        .where((v) => selectedVisitIds.contains(v.id))
        .toList(growable: false);
    if (selected.isEmpty) return false;
    return selectedVisitsExportReady(selected, excludedVisitIds);
  }

  void toggleVisit(String visitId) {
    if (selectedVisitIds.contains(visitId)) {
      selectedVisitIds.remove(visitId);
    } else {
      selectedVisitIds.add(visitId);
    }
  }

  Future<void> createExport() async {
    if (!canManage) return;
    final visitIds = selectedVisitIds.toList(growable: false);
    if (visitIds.isEmpty) {
      errorMessage.value = 'Select at least one completed visit.';
      return;
    }
    final selected = exportableVisits
        .where((v) => visitIds.contains(v.id))
        .toList(growable: false);
    if (!selectedVisitsExportReady(selected, excludedVisitIds)) {
      errorMessage.value =
          'Fix blocked pre-flight items before creating an export.';
      return;
    }

    isSaving.value = true;
    errorMessage.value = null;
    lastVisitErrors.clear();
    try {
      final created = await _repository.createInvoiceExport(
        InvoiceExportCreateRequest(visitIds: visitIds),
      );
      selectedVisitIds.clear();
      await loadAll();
      tabIndex.value = 0;
      if (!Get.testMode) {
        Get.snackbar(
          'Export created',
          '${created.lineCount} line${created.lineCount == 1 ? '' : 's'} · '
          '${created.currencyCode} ${created.totalAmount.toStringAsFixed(2)}',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          backgroundColor: AppColors.primary,
          colorText: AppColors.onPrimary,
        );
      }
      openDetail(created);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      lastVisitErrors.assignAll(_mapVisitErrors(e));
      _applyExcludedFromVisitErrors(lastVisitErrors);
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isSaving.value = false;
    }
  }

  List<InvoiceExportVisitError> _mapVisitErrors(AppFailure failure) {
    if (failure.visitErrors.isNotEmpty) {
      return failure.visitErrors
          .map(
            (row) => InvoiceExportVisitError(
              visitId: row['visit_id'] ?? '',
              code: row['code'] ?? 'unknown',
              message: row['message'] ??
                  invoiceExportErrorMessage(row['code'] ?? 'unknown'),
            ),
          )
          .where((e) => e.visitId.isNotEmpty)
          .toList(growable: false);
    }
    if (failure.code == 'visit_already_exported') {
      return selectedVisitIds
          .map(
            (id) => InvoiceExportVisitError(
              visitId: id,
              code: failure.code,
              message: failure.message,
            ),
          )
          .toList(growable: false);
    }
    return const [];
  }

  void _applyExcludedFromVisitErrors(List<InvoiceExportVisitError> errors) {
    for (final err in errors) {
      if (err.code == 'visit_already_exported') {
        excludedVisitIds.add(err.visitId);
        selectedVisitIds.remove(err.visitId);
      }
    }
    exportableVisits.removeWhere((v) => excludedVisitIds.contains(v.id));
    excludedVisitIds.refresh();
  }

  void openDetail(InvoiceExportOut export) {
    Get.toNamed(
      AppRoutes.staffBillingExportDetail,
      parameters: {'id': export.id},
      arguments: export,
    );
  }
}
