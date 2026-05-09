import 'dart:io';

import 'package:dio/dio.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_constants.dart';
import '../data/models/attendance/employee_model.dart';
import '../data/models/payment/payment_report_row.dart';
import '../data/repositories/payment_repository.dart';
import '../themes/app_colors.dart';

class PaymentsReportController extends GetxController {
  PaymentsReportController({required PaymentRepository repository}) : _repository = repository;

  final PaymentRepository _repository;

  final fromDate = Rx<DateTime?>(null);
  final toDate = Rx<DateTime?>(null);
  final isLoading = false.obs;
  final rows = <PaymentReportRow>[].obs;

  final employees = <EmployeeModel>[].obs;
  final selectedEmployee = Rxn<EmployeeModel>();

  final branchFilterOptions = const [
    BranchFilterOption(label: 'All Branches', branchId: null),
    BranchFilterOption(label: 'Current Branch', branchId: AppConstants.branchId),
  ];
  final selectedBranchId = RxnString();

  @override
  void onInit() {
    super.onInit();
    loadEmployees();
  }

  Future<void> loadEmployees() async {
    try {
      final items = await _repository.getEmployees();
      employees.assignAll(items);
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e));
    } catch (_) {
      _showError('Failed to load employees.');
    }
  }

  Future<void> setFromDate(BuildContext context) async {
    final picked = await _pickDate(context, fromDate.value);
    if (picked != null) fromDate.value = picked;
  }

  Future<void> setToDate(BuildContext context) async {
    final picked = await _pickDate(context, toDate.value);
    if (picked != null) toDate.value = picked;
  }

  String formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> fetchReport() async {
    final from = fromDate.value;
    final to = toDate.value;
    if (from == null || to == null) {
      Get.snackbar(
        'Validation Error',
        'Please select both from and to dates.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
      return;
    }
    if (from.isAfter(to)) {
      Get.snackbar(
        'Validation Error',
        'From date cannot be after to date.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
      return;
    }

    try {
      isLoading.value = true;
      final data = await _repository.getPaymentsReport(
        from: formatDate(from),
        to: formatDate(to),
        employeeId: selectedEmployee.value?.id,
        branchId: selectedBranchId.value,
      );
      rows.assignAll(data);
      if (rows.isEmpty) {
        Get.snackbar(
          'Report',
          'No payment records found for selected filters.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e));
    } catch (_) {
      _showError('Failed to generate report.');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> exportToExcel() async {
    if (rows.isEmpty) {
      Get.snackbar(
        'Export Error',
        'No report data available to export.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );
      final excel = Excel.createExcel();
      final sheet = excel['Payments Report'];
      excel.setDefaultSheet('Payments Report');
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      sheet.appendRow([
        TextCellValue('Employee Name'),
        TextCellValue('Employee Code'),
        TextCellValue('Payment Date'),
        TextCellValue('Amount Paid'),
        TextCellValue('Currency'),
        TextCellValue('Method'),
        TextCellValue('Reference No'),
      ]);

      for (final row in rows) {
        sheet.appendRow([
          TextCellValue(row.employeeName),
          TextCellValue(row.employeeCode),
          TextCellValue(row.paymentDate),
          DoubleCellValue(row.amountPaid),
          TextCellValue(row.currencyCode),
          TextCellValue(row.paymentMethod ?? '-'),
          TextCellValue(row.referenceNo ?? '-'),
        ]);
      }

      final bytes = excel.save();
      if (bytes == null) {
        if (Get.isDialogOpen ?? false) Get.back();
        _showError('Failed to generate excel file.');
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final filename = 'payments_report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File('${directory.path}/$filename');
      file
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);

      if (Get.isDialogOpen ?? false) Get.back();

      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(file.path)], text: 'Payments Report');
    } catch (_) {
      if (Get.isDialogOpen ?? false) Get.back();
      _showError('Failed to export report.');
    }
  }

  Future<DateTime?> _pickDate(BuildContext context, DateTime? initial) {
    return showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
  }

  String _extractErrorMessage(DioException e) {
    final code = e.response?.statusCode;
    final data = e.response?.data;
    String? detail;
    if (data is Map<String, dynamic> && data['detail'] is String) {
      detail = data['detail'] as String;
    }
    final fallback = switch (code) {
      400 => 'Invalid filters. Please review report dates and options.',
      403 => 'You are not allowed to view payment reports.',
      404 => 'Requested report resource was not found.',
      _ => 'Unable to fetch payment report.',
    };
    return detail ?? fallback;
  }

  void _showError(String message) {
    Get.snackbar(
      'Error',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.error,
      colorText: Colors.white,
    );
  }
}

class BranchFilterOption {
  const BranchFilterOption({required this.label, required this.branchId});

  final String label;
  final String? branchId;
}
