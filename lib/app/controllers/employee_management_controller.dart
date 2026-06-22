import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/employee_detail_controller.dart';
import '../data/models/attendance/employee_model.dart';
import '../data/repositories/employee_repository.dart';
import '../routes/app_navigation.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';
import '../utils/employee_clock_status.dart';
import '../views/shell/pane_controller_registry.dart';
import '../views/shell/pane_tags.dart';

class EmployeeManagementController extends GetxController {
  EmployeeManagementController({required EmployeeRepository repository})
      : _repository = repository;

  final EmployeeRepository _repository;

  final employees = <EmployeeModel>[].obs;
  final isLoading = false.obs;
  final elapsedTicker = 0.obs;
  final selectedEmployeeId = RxnString();

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

  Future<void> openEmployee(
    EmployeeModel employee, {
    required bool useTwoPane,
  }) async {
    if (useTwoPane) {
      selectedEmployeeId.value = employee.id;
      PaneControllerRegistry.ensureEmployeeDetail(
        employeeId: employee.id,
        onDeletedInPane: _onEmployeeDeletedInPane,
      );
      return;
    }

    final result = await Get.toNamed(
      AppRoutes.employeeDetail,
      arguments: employee.id,
    );
    await fetchEmployees();
    if (result is String && result.isNotEmpty) {
      Get.snackbar(
        'Deleted',
        result,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success,
        colorText: AppColors.textLight,
        icon: const Icon(Icons.check_circle, color: Colors.white),
      );
    }
  }

  void clearPaneSelection() {
    selectedEmployeeId.value = null;
    PaneControllerRegistry.disposeEmployeeDetail();
  }

  void _onEmployeeDeletedInPane() {
    clearPaneSelection();
    fetchEmployees();
    Get.snackbar(
      'Deleted',
      'Employee deleted successfully.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.success,
      colorText: AppColors.textLight,
      icon: const Icon(Icons.check_circle, color: Colors.white),
    );
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
    if (Get.isRegistered<EmployeeDetailController>(tag: PaneTags.employeeDetail)) {
      PaneControllerRegistry.disposeEmployeeDetail();
    }
    _elapsedTimer?.cancel();
    super.onClose();
  }
}
