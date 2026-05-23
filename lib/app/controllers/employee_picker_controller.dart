import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/models/attendance/employee_model.dart';
import '../data/repositories/payroll_repository.dart';
import '../routes/route_args.dart';
import '../themes/app_colors.dart';

class EmployeePickerController extends GetxController {
  EmployeePickerController({required PayrollRepository repository})
      : _repository = repository;

  final PayrollRepository _repository;

  final employees = <EmployeeModel>[].obs;
  final filteredEmployees = <EmployeeModel>[].obs;
  final searchController = TextEditingController();
  final isLoading = false.obs;

  String get title {
    final args = Get.arguments;
    if (args is EmployeePickerArgs && args.title != null) {
      return args.title!;
    }
    return 'Select Employee';
  }

  @override
  void onInit() {
    super.onInit();
    loadEmployees();
  }

  Future<void> loadEmployees() async {
    try {
      isLoading.value = true;
      final items = await _repository.getEmployees();
      employees.assignAll(items);
      filteredEmployees.assignAll(items);
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e));
    } catch (_) {
      _showError('Failed to load employees.');
    } finally {
      isLoading.value = false;
    }
  }

  void filterEmployees(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      filteredEmployees.assignAll(employees);
      return;
    }
    filteredEmployees.assignAll(
      employees.where(
        (e) =>
            e.fullName.toLowerCase().contains(q) ||
            e.employeeCode.toLowerCase().contains(q),
      ),
    );
  }

  void selectEmployee(EmployeeModel employee) {
    Get.back(result: EmployeePickerResult(employee));
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

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }
}
