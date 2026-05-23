import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/attendance_api_client.dart';
import '../routes/app_routes.dart';
import '../routes/route_args.dart';
import '../themes/app_colors.dart';

class CreateEmployeeController extends GetxController {
  // ── Form Key ─────────────────────────────────────────────────
  final formKey = GlobalKey<FormState>();

  // ── Form Text Controllers ─────────────────────────────────────
  final employeeCodeController = TextEditingController();
  final fullNameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();

  // ── Observable State ─────────────────────────────────────────
  final isLoading = false.obs;

  // ── Helpers ──────────────────────────────────────────────────

  /// Returns today's date formatted as `yyyy-MM-dd` using Dart core only.
  String get _todayFormatted {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  // ── API Call ─────────────────────────────────────────────────
  Future<void> createEmployee() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    isLoading.value = true;
    try {
      final dio = Get.find<AttendanceApiClient>().dio;

      final payload = <String, dynamic>{
        'employee_code': employeeCodeController.text.trim(),
        'full_name': fullNameController.text.trim(),
        'branch_id': AppConstants.branchId,
        'tenant_id': AppConstants.tenantId,
        'phone': phoneController.text.trim(),
        'email': emailController.text.trim(),
        'dob': _todayFormatted,
      };

      final response = await dio.post('/v1/employees', data: payload);

      if (response.statusCode == 201) {
        final data = response.data;
        final newEmployeeId = data is Map<String, dynamic>
            ? data['id'] as String?
            : null;
        _clearForm();
        if (newEmployeeId != null && newEmployeeId.isNotEmpty) {
          _offerInitialRate(newEmployeeId);
        } else {
          Get.snackbar(
            'Success',
            'Employee created successfully',
            backgroundColor: AppColors.success,
            colorText: AppColors.textLight,
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(16),
            borderRadius: 12,
            duration: const Duration(seconds: 3),
            icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
          );
          Get.back(result: true);
        }
      }
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e));
    } catch (e) {
      _showError(e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  // ── Private Helpers ───────────────────────────────────────────
  void _offerInitialRate(String employeeId) {
    Get.offNamed(
      AppRoutes.createEmployeeSuccess,
      arguments: EmployeeCreatedArgs(employeeId: employeeId),
    );
  }

  void _clearForm() {
    employeeCodeController.clear();
    fullNameController.clear();
    phoneController.clear();
    emailController.clear();
    formKey.currentState?.reset();
  }

  void _showError(String message) {
    Get.snackbar(
      'Error',
      message,
      backgroundColor: AppColors.error,
      colorText: AppColors.textLight,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 4),
      icon: const Icon(Icons.error_rounded, color: Colors.white),
    );
  }

  String _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map) {
          return first['msg']?.toString() ?? detail.toString();
        }
      }
    }
    return e.message ?? 'An unexpected error occurred. Please try again.';
  }

  @override
  void onClose() {
    employeeCodeController.dispose();
    fullNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    super.onClose();
  }
}
