import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/models/attendance/employee_model.dart';
import '../data/repositories/payroll_repository.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';

class PayrollMainController extends GetxController {
  PayrollMainController({required PayrollRepository repository})
      : _repository = repository;

  final PayrollRepository _repository;

  final employees = <EmployeeModel>[].obs;
  final isLoadingEmployees = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadEmployees();
  }

  Future<void> loadEmployees() async {
    try {
      isLoadingEmployees.value = true;
      employees.assignAll(await _repository.getEmployees());
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e));
    } catch (_) {
      _showError('Failed to load employees.');
    } finally {
      isLoadingEmployees.value = false;
    }
  }

  void openPeriods() => Get.toNamed(AppRoutes.payrollPeriods);

  void openSummaryReport() => Get.toNamed(AppRoutes.payrollSummaryReport);

  Future<void> openEmployeeRates(BuildContext context) async {
    final employeeId = await _pickEmployee(context);
    if (employeeId != null) {
      Get.toNamed(AppRoutes.payrollEmployeeRates, arguments: employeeId);
    }
  }

  Future<void> openEmployeeBalance(BuildContext context) async {
    final employeeId = await _pickEmployee(context);
    if (employeeId != null) {
      Get.toNamed(AppRoutes.payrollEmployeeBalance, arguments: employeeId);
    }
  }

  Future<String?> _pickEmployee(BuildContext context) async {
    if (employees.isEmpty) {
      await loadEmployees();
    }
    if (employees.isEmpty) {
      _showError('No employees available.');
      return null;
    }

    return Get.dialog<String>(
      AlertDialog(
        title: const Text('Select Employee'),
        content: SizedBox(
          width: double.maxFinite,
          height: 320,
          child: ListView.builder(
            itemCount: employees.length,
            itemBuilder: (context, index) {
              final employee = employees[index];
              return ListTile(
                title: Text(employee.fullName),
                subtitle: Text(employee.employeeCode),
                onTap: () => Get.back(result: employee.id),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
        ],
      ),
    );
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
