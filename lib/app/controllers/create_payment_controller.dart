import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/models/attendance/employee_model.dart';
import '../data/models/payment/create_payment_request.dart';
import '../data/repositories/payment_repository.dart';
import '../themes/app_colors.dart';

class CreatePaymentController extends GetxController {
  CreatePaymentController({required PaymentRepository repository}) : _repository = repository;

  final PaymentRepository _repository;

  final formKey = GlobalKey<FormState>();

  final amountController = TextEditingController();
  final referenceNoController = TextEditingController();
  final payrollResultIdController = TextEditingController();
  final notesController = TextEditingController();
  final employeeSearchController = TextEditingController();

  final employees = <EmployeeModel>[].obs;
  final filteredEmployees = <EmployeeModel>[].obs;
  final selectedEmployee = Rxn<EmployeeModel>();

  final paymentDate = DateTime.now().obs;
  final selectedCurrencyCode = 'USD'.obs;
  final selectedPaymentMethod = RxnString();
  final isLoading = false.obs;
  final isLoadingEmployees = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadEmployees();
  }

  Future<void> loadEmployees() async {
    try {
      isLoadingEmployees.value = true;
      final items = await _repository.getEmployees();
      employees.assignAll(items);
      filteredEmployees.assignAll(items);
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e));
    } catch (_) {
      _showError('Failed to load employees.');
    } finally {
      isLoadingEmployees.value = false;
    }
  }

  void filterEmployees(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      filteredEmployees.assignAll(employees);
      return;
    }
    filteredEmployees.assignAll(
      employees.where((employee) {
        return employee.fullName.toLowerCase().contains(normalized) ||
            employee.employeeCode.toLowerCase().contains(normalized);
      }),
    );
  }

  void selectEmployee(EmployeeModel employee) {
    selectedEmployee.value = employee;
    employeeSearchController.clear();
    filteredEmployees.assignAll(employees);
  }

  Future<void> setPaymentDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: paymentDate.value,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      paymentDate.value = picked;
    }
  }

  String formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String? validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) return 'Amount is required';
    final amount = double.tryParse(value.trim());
    if (amount == null) return 'Enter a valid amount';
    if (amount < 0) return 'Amount must be zero or more';
    return null;
  }

  Future<void> submitPayment() async {
    final isFormValid = formKey.currentState?.validate() ?? true;
    if (!isFormValid) return;

    final employee = selectedEmployee.value;
    if (employee == null) {
      _showSnackbar(
        'Validation Error',
        'Please select an employee.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
      return;
    }

    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount < 0) {
      _showSnackbar(
        'Validation Error',
        'Please enter a valid amount.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
      return;
    }

    final request = CreatePaymentRequest(
      employeeId: employee.id,
      paymentDate: formatDate(paymentDate.value),
      amountPaid: amount,
      currencyCode: selectedCurrencyCode.value,
      paymentMethod: selectedPaymentMethod.value,
      referenceNo: _toNullable(referenceNoController.text),
      payrollResultId: _toNullable(payrollResultIdController.text),
      notes: _toNullable(notesController.text),
    );

    try {
      isLoading.value = true;
      await _repository.createPayment(request);
      _showSnackbar(
        'Success',
        'Payment created successfully.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success,
        colorText: Colors.white,
      );
      clearForm();
      if (Get.key.currentState?.canPop() ?? false) {
        Get.back();
      }
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e));
    } catch (_) {
      _showError('Failed to create payment.');
    } finally {
      isLoading.value = false;
    }
  }

  String? _toNullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _extractErrorMessage(DioException e) {
    final code = e.response?.statusCode;
    final data = e.response?.data;
    String? detail;
    if (data is Map<String, dynamic>) {
      final raw = data['detail'];
      if (raw is String) detail = raw;
    }
    final fallback = switch (code) {
      400 => 'Invalid payment payload. Please review all fields.',
      403 => 'You are not allowed to create payments.',
      404 => 'Employee or payroll result was not found.',
      _ => 'Failed to create payment. Please try again.',
    };
    return detail ?? fallback;
  }

  void _showError(String message) {
    _showSnackbar(
      'Error',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.error,
      colorText: Colors.white,
    );
  }

  void _showSnackbar(
    String title,
    String message, {
    SnackPosition snackPosition = SnackPosition.BOTTOM,
    Color? backgroundColor,
    Color? colorText,
  }) {
    if (Get.key.currentState?.overlay == null) return;
    Get.snackbar(
      title,
      message,
      snackPosition: snackPosition,
      backgroundColor: backgroundColor,
      colorText: colorText,
    );
  }

  void clearForm() {
    amountController.clear();
    referenceNoController.clear();
    payrollResultIdController.clear();
    notesController.clear();
    selectedEmployee.value = null;
    selectedCurrencyCode.value = 'USD';
    selectedPaymentMethod.value = null;
    paymentDate.value = DateTime.now();
  }

  @override
  void onClose() {
    amountController.dispose();
    referenceNoController.dispose();
    payrollResultIdController.dispose();
    notesController.dispose();
    employeeSearchController.dispose();
    super.onClose();
  }
}
