import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/models/payroll/payroll_date_utils.dart';
import '../data/models/payroll/period_out.dart';
import '../data/repositories/payroll_repository.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';

class PayrollPeriodDetailController extends GetxController {
  PayrollPeriodDetailController({required PayrollRepository repository})
      : _repository = repository;

  final PayrollRepository _repository;

  late final Rx<PeriodOut> period;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is! PeriodOut) {
      Get.back();
      return;
    }
    period = args.obs;
  }

  Future<void> calculatePeriod() async {
    try {
      isLoading.value = true;
      final updated = await _repository.calculatePeriod(period.value.id);
      period.value = updated;
      Get.snackbar(
        'Success',
        'Period calculated.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success,
        colorText: AppColors.textLight,
      );
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e));
    } catch (_) {
      _showError('Failed to calculate period.');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> closePeriod() async {
    try {
      isLoading.value = true;
      final updated = await _repository.closePeriod(period.value.id);
      period.value = updated;
      Get.snackbar(
        'Success',
        'Period closed.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success,
        colorText: AppColors.textLight,
      );
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e));
    } catch (_) {
      _showError('Failed to close period.');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> exportCsv() async {
    try {
      isLoading.value = true;
      final bytes = await _repository.exportPeriodCsv(period.value.id);
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/payroll_period_${period.value.id}.csv',
      );
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Payroll period export');
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e));
    } catch (_) {
      _showError('Failed to export CSV.');
    } finally {
      isLoading.value = false;
    }
  }

  void viewResults() {
    Get.toNamed(AppRoutes.payrollPeriodResults, arguments: period.value.id);
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
