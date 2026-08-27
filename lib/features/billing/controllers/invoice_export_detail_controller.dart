import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/utils/download_bytes.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/models/billing_models.dart';
import '../data/repositories/billing_repository.dart';

String invoiceExportCsvFilename(String exportId) {
  final short =
      exportId.length <= 8 ? exportId : exportId.substring(0, 8);
  return 'invoice-export-$short.csv';
}

class InvoiceExportDetailController extends GetxController {
  InvoiceExportDetailController({
    required BillingRepository repository,
    required SessionService session,
  }) : _repository = repository,
       _session = session;

  final BillingRepository _repository;
  final SessionService _session;

  final selected = Rxn<InvoiceExportOut>();
  final isLoading = false.obs;
  final isDownloadingCsv = false.obs;
  final isVoiding = false.obs;
  final errorMessage = RxnString();

  bool get canView => _session.canViewBilling;
  bool get canManage => _session.canManageBilling;

  String? get exportId =>
      Get.parameters['id'] ??
      (Get.arguments is String ? Get.arguments as String : null) ??
      (Get.arguments is InvoiceExportOut
          ? (Get.arguments as InvoiceExportOut).id
          : null);

  bool get canVoid =>
      canManage && selected.value?.isFinalized == true && !isVoiding.value;

  @override
  void onInit() {
    super.onInit();
    final arg = Get.arguments;
    if (arg is InvoiceExportOut) {
      selected.value = arg;
    }
    load();
  }

  Future<void> load() async {
    if (!canView) {
      errorMessage.value = 'Missing billing.view permission.';
      return;
    }
    final id = exportId;
    if (id == null || id.isEmpty) {
      errorMessage.value = 'Export not found.';
      return;
    }
    isLoading.value = true;
    errorMessage.value = null;
    try {
      selected.value = await _repository.getInvoiceExport(id);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> downloadCsv() async {
    final id = exportId;
    if (id == null || id.isEmpty || !canView) return;

    isDownloadingCsv.value = true;
    errorMessage.value = null;
    try {
      final csv = await _repository.downloadInvoiceExportCsv(id);
      if (!Get.testMode) {
        await downloadBytesAsFile(
          bytes: Uint8List.fromList(utf8.encode(csv)),
          filename: invoiceExportCsvFilename(id),
          mimeType: 'text/csv',
        );
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isDownloadingCsv.value = false;
    }
  }

  Future<void> confirmAndVoidExport(BuildContext context) async {
    if (!canVoid) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Void this export?'),
        content: const Text(
          'Visits in this export will become billable again and can be included '
          'in a new export. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Void export'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await voidExport();
  }

  Future<void> voidExport() async {
    final id = exportId;
    if (id == null || id.isEmpty || !canManage) return;
    if (selected.value?.isFinalized != true) return;

    isVoiding.value = true;
    errorMessage.value = null;
    try {
      selected.value = await _repository.voidInvoiceExport(id);
      if (!Get.testMode) {
        AppToast.success('Export voided', 'Visits can be exported again.');
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isVoiding.value = false;
    }
  }
}
