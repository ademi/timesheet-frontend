import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/constants/payment_currencies.dart';
import '../data/models/attendance/employee_model.dart';
import '../data/models/payment/create_payment_request.dart';
import '../data/models/payroll/payroll_date_utils.dart';
import '../data/models/payroll/period_out.dart';
import '../data/models/payroll/result_out.dart';
import '../data/repositories/payment_repository.dart';
import '../data/repositories/payroll_repository.dart';
import '../routes/app_navigation.dart';
import '../routes/app_routes.dart';
import '../routes/route_args.dart';
import '../themes/app_colors.dart';

class CreatePaymentController extends GetxController {
  CreatePaymentController({
    required PaymentRepository paymentRepository,
    required PayrollRepository payrollRepository,
  })  : _paymentRepository = paymentRepository,
        _payrollRepository = payrollRepository;

  final PaymentRepository _paymentRepository;
  final PayrollRepository _payrollRepository;

  final formKey = GlobalKey<FormState>();

  final amountController = TextEditingController();
  final referenceNoController = TextEditingController();
  final notesController = TextEditingController();
  final employees = <EmployeeModel>[].obs;
  final periods = <PeriodOut>[].obs;
  final periodResults = <ResultOut>[].obs;

  final selectedEmployee = Rxn<EmployeeModel>();
  final selectedPeriod = Rxn<PeriodOut>();
  final selectedResult = Rxn<ResultOut>();

  final paymentDate = DateTime.now().obs;
  final selectedCurrencyCode = PaymentCurrencies.defaultCode.obs;
  final selectedPaymentMethod = RxnString();
  final isLoading = false.obs;
  final isLoadingPeriods = false.obs;
  final isLoadingResults = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadEmployees();
    loadPeriods();
    _applyRouteArguments();
  }

  void _applyRouteArguments() {
    final args = Get.arguments;
    if (args is Map) {
      final periodId = args['periodId'] as String?;
      if (periodId != null) {
        ever(periods, (_) {
          final match = periods.firstWhereOrNull((p) => p.id == periodId);
          if (match != null) {
            selectPeriod(match);
          }
        });
      }
      final employeeId = args['employeeId'] as String?;
      if (employeeId != null) {
        ever(employees, (_) {
          final match = employees.firstWhereOrNull((e) => e.id == employeeId);
          if (match != null) {
            selectEmployee(match);
          }
        });
      }
    }
  }

  Future<void> loadEmployees() async {
    try {
      final items = await _paymentRepository.getEmployees();
      employees.assignAll(items);
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e));
    } catch (_) {
      _showError('Failed to load employees.');
    }
  }

  Future<void> openEmployeePicker() async {
    final result = await pushNamedResult<EmployeePickerResult>(
      AppRoutes.employeePicker,
      arguments: const EmployeePickerArgs(title: 'Select Employee'),
    );
    if (result != null) {
      selectEmployee(result.employee);
    }
  }

  Future<void> loadPeriods() async {
    try {
      isLoadingPeriods.value = true;
      final all = await _payrollRepository.getPeriods();
      periods.assignAll(
        all.where((p) => p.status == 'calculated' || p.status == 'closed'),
      );
      final args = Get.arguments;
      if (args is Map && args['periodId'] is String) {
        final periodId = args['periodId'] as String;
        final match = periods.firstWhereOrNull((p) => p.id == periodId);
        if (match != null) selectPeriod(match);
      }
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e));
    } catch (_) {
      _showError('Failed to load payroll periods.');
    } finally {
      isLoadingPeriods.value = false;
    }
  }

  Future<void> loadResultsForSelection() async {
    final period = selectedPeriod.value;
    final employee = selectedEmployee.value;
    if (period == null || employee == null) {
      periodResults.clear();
      selectedResult.value = null;
      return;
    }

    try {
      isLoadingResults.value = true;
      final all = await _payrollRepository.getPeriodResults(period.id);
      periodResults.assignAll(
        all.where((r) => r.employeeId == employee.id),
      );
      if (periodResults.length == 1) {
        selectResult(periodResults.first);
      } else {
        selectedResult.value = null;
      }
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e));
    } catch (_) {
      _showError('Failed to load payroll results for this employee.');
    } finally {
      isLoadingResults.value = false;
    }
  }

  void selectEmployee(EmployeeModel employee) {
    selectedEmployee.value = employee;
    selectedCurrencyCode.value = employee.defaultCurrencyCode;
    loadResultsForSelection();
  }

  void selectPeriod(PeriodOut? period) {
    selectedPeriod.value = period;
    selectedResult.value = null;
    periodResults.clear();
    loadResultsForSelection();
  }

  void selectResult(ResultOut? result) {
    selectedResult.value = result;
    if (result != null) {
      amountController.text = result.amountDue.toStringAsFixed(2);
    }
  }

  String periodLabel(PeriodOut period) {
    return '${fmtPayrollDate(period.periodStart)} → ${fmtPayrollDate(period.periodEnd)} (${period.status})';
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

  String formatDate(DateTime date) => fmtPayrollDate(date);

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
    final period = selectedPeriod.value;
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
    if (period == null) {
      _showSnackbar(
        'Validation Error',
        'Please select a payroll period.',
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
      periodId: period.id,
      paymentDate: formatDate(paymentDate.value),
      amountPaid: amount,
      currencyCode: selectedCurrencyCode.value,
      paymentMethod: selectedPaymentMethod.value,
      referenceNo: _toNullable(referenceNoController.text),
      payrollResultId: selectedResult.value?.id,
      notes: _toNullable(notesController.text),
    );

    try {
      isLoading.value = true;
      await _paymentRepository.createPayment(request);
      _showSnackbar(
        'Success',
        'Payment created successfully.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success,
        colorText: Colors.white,
        icon: const Icon(Icons.check_circle, color: Colors.white),
      );
      await Future<void>.delayed(const Duration(milliseconds: 700));
      Get.offNamed(AppRoutes.paymentMain);
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
      404 => 'Employee, period, or payroll result was not found.',
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
    Widget? icon,
  }) {
    if (Get.key.currentState?.overlay == null) return;
    Get.snackbar(
      title,
      message,
      snackPosition: snackPosition,
      backgroundColor: backgroundColor,
      colorText: colorText,
      icon: icon,
    );
  }

  void clearForm() {
    amountController.clear();
    referenceNoController.clear();
    notesController.clear();
    selectedEmployee.value = null;
    selectedPeriod.value = null;
    selectedResult.value = null;
    periodResults.clear();
    selectedCurrencyCode.value = PaymentCurrencies.defaultCode;
    selectedPaymentMethod.value = null;
    paymentDate.value = DateTime.now();
  }

  @override
  void onClose() {
    amountController.dispose();
    referenceNoController.dispose();
    notesController.dispose();
    super.onClose();
  }
}
