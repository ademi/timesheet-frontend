import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../data/models/attendance/employee_model.dart';
import '../data/models/payment/payment_out.dart';
import '../data/repositories/payment_repository.dart';
import '../themes/app_colors.dart';

class EmployeePaymentHistoryController extends GetxController {
  EmployeePaymentHistoryController({required PaymentRepository repository})
      : _repository = repository;

  final PaymentRepository _repository;

  final employees = <EmployeeModel>[].obs;
  final selectedEmployee = Rxn<EmployeeModel>();
  final payments = <PaymentOut>[].obs;
  final isLoading = false.obs;
  final isLoadingEmployees = false.obs;
  final errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    _initialize();
  }

  Future<void> _initialize() async {
    await loadEmployees();
    final args = Get.arguments;
    if (args is Map && args['employeeId'] is String) {
      final employeeId = args['employeeId'] as String;
      final matched = employees.firstWhereOrNull((e) => e.id == employeeId);
      if (matched != null) {
        selectedEmployee.value = matched;
        await fetchHistory();
      }
    }
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

  Future<void> fetchHistory() async {
    final employee = selectedEmployee.value;
    if (employee == null) {
      Get.snackbar(
        'Validation Error',
        'Please select an employee first.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.textLight,
      );
      return;
    }

    try {
      isLoading.value = true;
      errorMessage.value = null;
      final list = await _repository.getEmployeePaymentHistory(employee.id);
      list.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
      payments.assignAll(list);
    } on DioException catch (e) {
      final message = _extractErrorMessage(e);
      errorMessage.value = message;
      _showError(message);
    } catch (_) {
      const message = 'Failed to load employee payment history.';
      errorMessage.value = message;
      _showError(message);
    } finally {
      isLoading.value = false;
    }
  }

  String _extractErrorMessage(DioException e) {
    final code = e.response?.statusCode;
    final data = e.response?.data;
    String? detail;
    if (data is Map<String, dynamic> && data['detail'] is String) {
      detail = data['detail'] as String;
    }
    final fallback = switch (code) {
      400 => 'Invalid employee request.',
      403 => 'You are not allowed to view payment history.',
      404 => 'Employee payment history not found.',
      _ => 'Unable to fetch payment history.',
    };
    return detail ?? fallback;
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
