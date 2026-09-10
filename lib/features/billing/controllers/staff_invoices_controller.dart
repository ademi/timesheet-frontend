import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../visits/data/models/visit_models.dart';
import '../../visits/data/repositories/visits_repository.dart';
import '../data/models/invoice_export_models.dart';
import '../data/repositories/billing_repository.dart';

class StaffInvoicesController extends GetxController {
  StaffInvoicesController({
    required BillingRepository billing,
    required VisitsRepository visits,
    required SessionService session,
    void Function(String title, String message)? successNotifier,
  }) : _billing = billing,
       _visits = visits,
       _session = session,
       _successNotifier = successNotifier {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    periodRange = DateTimeRange(start: today, end: today).obs;
  }

  final BillingRepository _billing;
  final VisitsRepository _visits;
  final SessionService _session;
  final void Function(String title, String message)? _successNotifier;

  final tabIndex = 0.obs;
  final exports = <InvoiceExportOut>[].obs;
  final selectedExport = Rxn<InvoiceExportOut>();
  final completedVisits = <VisitOut>[].obs;
  final selectedVisitIds = <String>{}.obs;

  final isLoadingExports = false.obs;
  final isLoadingVisits = false.obs;
  final isLoadingDetail = false.obs;
  final isSaving = false.obs;
  final isVoiding = false.obs;
  final isDownloading = false.obs;

  final exportListError = RxnString();
  final createError = RxnString();
  final detailError = RxnString();
  late final Rx<DateTimeRange> periodRange;

  bool get canView =>
      _session.hasPermission(AppPermissions.billingView) ||
      _session.hasPermission(AppPermissions.billingManage);
  bool get canDownload => _session.hasPermission(AppPermissions.billingView);
  bool get canManage => _session.hasPermission(AppPermissions.billingManage);

  @override
  void onInit() {
    super.onInit();
    final argument = Get.arguments;
    if (argument is InvoiceExportOut) {
      selectedExport.value = argument;
    } else if (argument is String && argument.isNotEmpty) {
      selectedExport.value = null;
      refreshExport(argument);
    }
    loadAll();
    final selected = selectedExport.value;
    if (selected != null) refreshExport(selected.id);
  }

  Future<void> loadAll() async {
    await Future.wait<void>([loadExports(), loadCompletedVisits()]);
  }

  Future<void> loadExports() async {
    if (!canView) {
      exportListError.value = 'Missing billing.view permission.';
      return;
    }
    isLoadingExports.value = true;
    exportListError.value = null;
    try {
      exports.assignAll(await _billing.listExports());
    } on AppFailure catch (error) {
      exportListError.value = error.message;
    } finally {
      isLoadingExports.value = false;
    }
  }

  Future<void> loadCompletedVisits() async {
    if (!canView) return;
    isLoadingVisits.value = true;
    createError.value = null;
    final range = periodRange.value;
    final from = DateTime.utc(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final to = DateTime.utc(
      range.end.year,
      range.end.month,
      range.end.day,
    ).add(const Duration(days: 1));
    try {
      completedVisits.assignAll(
        await _visits.listVisits(
          from: from,
          to: to,
          status: 'completed',
          paymentStatus: null,
        ),
      );
      selectedVisitIds.removeWhere(
        (id) => !completedVisits.any((visit) => visit.id == id),
      );
    } on AppFailure catch (error) {
      createError.value = error.message;
    } finally {
      isLoadingVisits.value = false;
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
    await loadCompletedVisits();
  }

  void toggleVisit(String visitId) {
    if (!canManage) return;
    if (selectedVisitIds.contains(visitId)) {
      selectedVisitIds.remove(visitId);
    } else {
      selectedVisitIds.add(visitId);
    }
  }

  Future<void> createExport() async {
    if (!canManage || isSaving.value) return;
    if (selectedVisitIds.isEmpty) {
      createError.value = 'Select at least one completed visit.';
      return;
    }

    isSaving.value = true;
    createError.value = null;
    try {
      final created = await _billing.createExport(
        InvoiceExportCreateRequest(
          visitIds: selectedVisitIds.toList(growable: false),
        ),
      );
      selectedExport.value = created;
      selectedVisitIds.clear();
      await loadExports();
      await loadCompletedVisits();
      tabIndex.value = 0;
      _success(
        'Invoice export created',
        '${created.lineCount} claim lines · '
            '${created.totalAmount.toStringAsFixed(2)} ${created.currencyCode}',
      );
    } on AppFailure catch (error) {
      createError.value = error.message;
    } finally {
      isSaving.value = false;
    }
  }

  void openExport(InvoiceExportOut export) {
    selectedExport.value = export;
    refreshExport(export.id);
    Get.toNamed(AppRoutes.staffInvoiceDetail, arguments: export);
  }

  Future<void> refreshSelectedExport() async {
    final selected = selectedExport.value;
    final argument = Get.arguments;
    final id =
        selected?.id ??
        (argument is InvoiceExportOut
            ? argument.id
            : argument is String
            ? argument
            : null);
    if (id != null && id.isNotEmpty) await refreshExport(id);
  }

  Future<void> refreshExport(String id) async {
    if (!canView) {
      detailError.value = 'Missing billing.view permission.';
      return;
    }
    isLoadingDetail.value = true;
    detailError.value = null;
    try {
      selectedExport.value = await _billing.getExport(id);
    } on AppFailure catch (error) {
      detailError.value = error.message;
    } finally {
      isLoadingDetail.value = false;
    }
  }

  Future<void> voidSelectedExport() async {
    final export = selectedExport.value;
    if (!canManage || export == null || export.isVoided || isVoiding.value) {
      return;
    }
    isVoiding.value = true;
    detailError.value = null;
    try {
      selectedExport.value = await _billing.voidExport(export.id);
      await loadExports();
      _success('Invoice export voided', 'Export ${export.id} is now voided.');
    } on AppFailure catch (error) {
      detailError.value = error.message;
    } finally {
      isVoiding.value = false;
    }
  }

  Future<void> downloadSelectedCsv() async {
    final export = selectedExport.value;
    if (!canDownload || export == null || isDownloading.value) return;
    isDownloading.value = true;
    try {
      final csv = await _billing.downloadCsv(export.id);
      await SharePlus.instance.share(
        ShareParams(
          title: 'Invoice export ${export.id}',
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(csv)),
              mimeType: 'text/csv',
              name: 'invoice-export-${export.id}.csv',
            ),
          ],
          fileNameOverrides: ['invoice-export-${export.id}.csv'],
        ),
      );
    } on AppFailure catch (error) {
      _downloadFailure(error.message);
    } catch (_) {
      _downloadFailure('Could not download invoice export CSV.');
    } finally {
      isDownloading.value = false;
    }
  }

  void _downloadFailure(String message) {
    Get.snackbar(
      'CSV download failed',
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      backgroundColor: AppColors.errorBackground,
      colorText: AppColors.error,
    );
  }

  void _success(String title, String message) {
    final notifier = _successNotifier;
    if (notifier != null) {
      notifier(title, message);
      return;
    }
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      backgroundColor: AppColors.primary,
      colorText: AppColors.onPrimary,
    );
  }
}
