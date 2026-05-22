import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../data/models/payroll/employee_balance_out.dart';
import '../data/repositories/payroll_repository.dart';
import '../themes/app_colors.dart';

class EmployeeBalanceController extends GetxController {
  EmployeeBalanceController({required PayrollRepository repository})
      : _repository = repository;

  final PayrollRepository _repository;

  late final String employeeId;
  final balance = Rxn<EmployeeBalanceOut>();
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is! String || args.isEmpty) {
      Get.back();
      return;
    }
    employeeId = args;
    loadBalance();
  }

  Future<void> loadBalance() async {
    try {
      isLoading.value = true;
      balance.value = await _repository.getEmployeeBalance(employeeId);
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e));
    } catch (_) {
      _showError('Failed to load employee balance.');
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
