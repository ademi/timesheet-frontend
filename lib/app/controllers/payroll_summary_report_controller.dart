import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/models/payroll/payroll_date_utils.dart';
import '../data/models/payroll/payroll_summary_row.dart';
import '../data/models/payroll/period_out.dart';
import '../data/repositories/payroll_repository.dart';
import '../themes/app_colors.dart';

class PayrollSummaryReportController extends GetxController {
  PayrollSummaryReportController({required PayrollRepository repository})
      : _repository = repository;

  final PayrollRepository _repository;

  final periods = <PeriodOut>[].obs;
  final rows = <PayrollSummaryRow>[].obs;
  final source = ''.obs;
  final isLoading = false.obs;
  final usePeriodFilter = true.obs;

  final selectedPeriod = Rxn<PeriodOut>();
  final fromDate = Rxn<DateTime>();
  final toDate = Rxn<DateTime>();

  @override
  void onInit() {
    super.onInit();
    loadPeriods();
  }

  Future<void> loadPeriods() async {
    try {
      periods.assignAll(await _repository.getPeriods());
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e));
    } catch (_) {
      _showError('Failed to load periods.');
    }
  }

  void setFilterMode(bool usePeriod) {
    usePeriodFilter.value = usePeriod;
    if (usePeriod) {
      fromDate.value = null;
      toDate.value = null;
    } else {
      selectedPeriod.value = null;
    }
  }

  Future<void> setFromDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: fromDate.value ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) fromDate.value = picked;
  }

  Future<void> setToDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: toDate.value ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) toDate.value = picked;
  }

  Future<void> loadReport() async {
    if (usePeriodFilter.value) {
      if (selectedPeriod.value == null) {
        _showError('Please select a payroll period.');
        return;
      }
    } else {
      if (fromDate.value == null || toDate.value == null) {
        _showError('Please select both from and to dates.');
        return;
      }
      if (toDate.value!.isBefore(fromDate.value!)) {
        _showError('To date must be on or after from date.');
        return;
      }
    }

    try {
      isLoading.value = true;
      final response = await _repository.getSummaryReport(
        periodId: usePeriodFilter.value ? selectedPeriod.value?.id : null,
        fromDate: usePeriodFilter.value ? null : fromDate.value,
        toDate: usePeriodFilter.value ? null : toDate.value,
      );
      source.value = response['source'] as String? ?? '';
      rows.assignAll(_repository.parseSummaryRows(response));
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e));
    } catch (_) {
      _showError('Failed to load summary report.');
    } finally {
      isLoading.value = false;
    }
  }

  String formatDate(DateTime date) => fmtPayrollDate(date);

  String _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] is String) {
      return data['detail'] as String;
    }
    return e.message ?? 'An unexpected error occurred.';
  }

  void _showError(String message) {
    Get.snackbar(
      'Error',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.error,
      colorText: AppColors.textLight,
    );
  }
}
