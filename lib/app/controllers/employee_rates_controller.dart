import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../data/models/payroll/payroll_date_utils.dart';
import '../data/models/payroll/rate_out.dart';
import '../data/repositories/payroll_repository.dart';
import '../routes/app_navigation.dart';
import '../routes/app_routes.dart';
import '../routes/route_args.dart';
import '../themes/app_colors.dart';

class EmployeeRatesController extends GetxController {
  EmployeeRatesController({required PayrollRepository repository})
      : _repository = repository;

  final PayrollRepository _repository;

  late final String employeeId;
  final rates = <RateOut>[].obs;
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
    loadRates();
  }

  Future<void> loadRates() async {
    try {
      isLoading.value = true;
      rates.assignAll(await _repository.getRates(employeeId));
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e));
    } catch (_) {
      _showError('Failed to load employee rates.');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> openCreateForm() async {
    final saved = await pushNamedBool(
      AppRoutes.payrollEmployeeRateForm,
      arguments: EmployeeRateFormArgs(employeeId: employeeId),
    );
    if (saved) {
      await loadRates();
      _showSuccess('Rate created.');
    }
  }

  Future<void> openEditForm(RateOut rate) async {
    final saved = await pushNamedBool(
      AppRoutes.payrollEmployeeRateForm,
      arguments: EmployeeRateFormArgs(employeeId: employeeId, rate: rate),
    );
    if (saved) {
      await loadRates();
      _showSuccess('Rate updated.');
    }
  }

  void _showSuccess(String message) {
    Get.snackbar(
      'Success',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.success,
      colorText: AppColors.textLight,
    );
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
