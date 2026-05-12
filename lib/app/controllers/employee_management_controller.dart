import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../core/network/attendance_api_client.dart';
import '../data/models/attendance/employee_model.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';

class EmployeeManagementController extends GetxController {
  EmployeeManagementController({required Dio dio}) : _dio = dio;

  final Dio _dio;

  final employees = <EmployeeModel>[].obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchEmployees();
  }

  Future<void> fetchEmployees() async {
    try {
      isLoading.value = true;
      final response = await _dio.get<List<dynamic>>('/v1/employees');
      final data = response.data ?? <dynamic>[];
      employees.assignAll(
        data
            .whereType<Map<String, dynamic>>()
            .map(EmployeeModel.fromJson)
            .toList(),
      );
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e));
    } catch (_) {
      _showError('Failed to load employees.');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> goToCreateEmployee() async {
    final created = await Get.toNamed<bool>(AppRoutes.createEmployee);
    if (created == true) {
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

  static EmployeeManagementController fromGet() {
    return Get.find<EmployeeManagementController>();
  }

  static EmployeeManagementController createDefault() {
    return EmployeeManagementController(
      dio: Get.find<AttendanceApiClient>().dio,
    );
  }
}
