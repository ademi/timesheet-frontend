import 'dart:async';

import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../data/models/attendance/employee_model.dart';
import '../data/repositories/employee_repository.dart';
import '../routes/app_navigation.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';
import '../utils/employee_clock_status.dart';

class EmployeeManagementController extends GetxController {
  EmployeeManagementController({required EmployeeRepository repository})
      : _repository = repository;

  final EmployeeRepository _repository;

  final employees = <EmployeeModel>[].obs;
  final isLoading = false.obs;
  final elapsedTicker = 0.obs;

  Timer? _elapsedTimer;

  @override
  void onInit() {
    super.onInit();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsedTicker.value++;
    });
    fetchEmployees();
  }

  Future<void> fetchEmployees() async {
    try {
      isLoading.value = true;
      employees.assignAll(await _repository.listEmployeesWithClockStatus());
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e));
    } catch (e) {
      _showError('Failed to load employees.');
    } finally {
      isLoading.value = false;
    }
  }

  String formatClockDuration(EmployeeModel employee) {
    elapsedTicker.value;
    return formatEmployeeClockDuration(employee);
  }

  String clockStatusLabel(EmployeeModel employee) {
    return employeeClockStatusLabel(
      employee,
      formatClockDuration(employee),
    );
  }

  Future<void> goToCreateEmployee() async {
    final created = await pushNamedBool(AppRoutes.createEmployee);
    if (created) {
      await fetchEmployees();
    }
  }

  String _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String && detail.trim().isNotEmpty) return detail;
    }
    return e.message ?? 'Unable to fetch employees right now.';
  }

  void _showError(String message) {
    if (Get.key.currentState?.overlay == null) return;
    Get.snackbar(
      'Error',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.error,
      colorText: AppColors.textLight,
    );
  }

  @override
  void onClose() {
    _elapsedTimer?.cancel();
    super.onClose();
  }
}
