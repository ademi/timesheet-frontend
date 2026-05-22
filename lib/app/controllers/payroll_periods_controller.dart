import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/models/payroll/payroll_date_utils.dart';
import '../data/models/payroll/period_create_request.dart';
import '../data/models/payroll/period_out.dart';
import '../data/repositories/payroll_repository.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';

class PayrollPeriodsController extends GetxController {
  PayrollPeriodsController({required PayrollRepository repository})
      : _repository = repository;

  final PayrollRepository _repository;

  final periods = <PeriodOut>[].obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadPeriods();
  }

  Future<void> loadPeriods() async {
    try {
      isLoading.value = true;
      final list = await _repository.getPeriods();
      periods.assignAll(list);
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e));
    } catch (_) {
      _showError('Failed to load payroll periods.');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> createPeriod(BuildContext context) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (range == null) return;

    try {
      isLoading.value = true;
      final created = await _repository.createPeriod(
        PeriodCreateRequest(
          periodStart: range.start,
          periodEnd: range.end,
        ),
      );
      periods.insert(0, created);
      Get.snackbar(
        'Success',
        'Payroll period created.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success,
        colorText: AppColors.textLight,
      );
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e));
    } catch (_) {
      _showError('Failed to create payroll period.');
    } finally {
      isLoading.value = false;
    }
  }

  void openPeriodDetail(PeriodOut period) {
    Get.toNamed(AppRoutes.payrollPeriodDetail, arguments: period);
  }

  String formatDate(DateTime date) => fmtPayrollDate(date);

  Color statusColor(String status) {
    switch (status) {
      case 'calculated':
        return Colors.blue;
      case 'closed':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

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
