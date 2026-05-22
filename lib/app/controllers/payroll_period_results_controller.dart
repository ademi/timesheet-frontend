import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../data/models/payroll/result_out.dart';
import '../data/repositories/payroll_repository.dart';
import '../themes/app_colors.dart';

class PayrollPeriodResultsController extends GetxController {
  PayrollPeriodResultsController({required PayrollRepository repository})
      : _repository = repository;

  final PayrollRepository _repository;

  final results = <ResultOut>[].obs;
  final isLoading = false.obs;
  late final String periodId;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is! String || args.isEmpty) {
      Get.back();
      return;
    }
    periodId = args;
    loadResults();
  }

  Future<void> loadResults() async {
    try {
      isLoading.value = true;
      results.assignAll(await _repository.getPeriodResults(periodId));
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e));
    } catch (_) {
      _showError('Failed to load period results.');
    } finally {
      isLoading.value = false;
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
