import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../bindings/payroll_module_binding.dart';
import '../data/models/attendance/employee_model.dart';
import '../data/models/attendance/employee_update_request.dart';
import '../data/models/attendance/time_entry_out.dart';
import '../data/models/payroll/employee_balance_out.dart';
import '../data/models/payroll/payroll_date_utils.dart';
import '../data/models/payroll/period_out.dart';
import '../data/models/payroll/rate_out.dart';
import '../data/models/payroll/result_out.dart';
import '../data/repositories/employee_repository.dart';
import '../data/repositories/payroll_repository.dart';
import '../core/constants/payment_currencies.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';

class EmployeeDetailController extends GetxController {
  EmployeeDetailController({
    required EmployeeRepository employeeRepository,
    required PayrollRepository payrollRepository,
  })  : _employeeRepository = employeeRepository,
        _payrollRepository = payrollRepository;

  final EmployeeRepository _employeeRepository;
  final PayrollRepository _payrollRepository;

  late final String employeeId;

  final employee = Rxn<EmployeeModel>();
  final displayPeriod = Rxn<PeriodOut>();
  final rates = <RateOut>[].obs;
  final periodResult = Rxn<ResultOut>();
  final timeEntries = <TimeEntryOut>[].obs;
  final balance = Rxn<EmployeeBalanceOut>();

  final isLoading = false.obs;
  final isSaving = false.obs;
  final isEditing = false.obs;

  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final isActive = true.obs;
  final defaultCurrencyCode = PaymentCurrencies.defaultCode.obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is! String || args.isEmpty) {
      Get.back();
      return;
    }
    bindEmployeeId(args);
  }

  void bindEmployeeId(String id) {
    employeeId = id;
    loadAll();
  }

  Future<void> loadAll() async {
    try {
      isLoading.value = true;
      final emp = await _employeeRepository.getEmployee(employeeId);
      employee.value = emp;
      _populateForm(emp);

      final periods = await _payrollRepository.getPeriods();
      displayPeriod.value = _pickDisplayPeriod(periods);

      rates.assignAll(await _payrollRepository.getRates(employeeId));
      balance.value = await _payrollRepository.getEmployeeBalance(employeeId);

      final period = displayPeriod.value;
      if (period != null) {
        if (period.status == 'calculated' || period.status == 'closed') {
          final results =
              await _payrollRepository.getPeriodResults(period.id);
          periodResult.value = results
              .where((r) => r.employeeId == employeeId)
              .firstOrNull;
        } else {
          periodResult.value = null;
        }
        timeEntries.assignAll(
          await _employeeRepository.listTimeEntries(
            employeeId: employeeId,
            from: period.periodStart,
            to: period.periodEnd,
          ),
        );
      } else {
        periodResult.value = null;
        timeEntries.clear();
      }
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e));
    } catch (_) {
      _showError('Failed to load employee details.');
    } finally {
      isLoading.value = false;
    }
  }

  PeriodOut? _pickDisplayPeriod(List<PeriodOut> periods) {
    final payable = periods
        .where((p) => p.status == 'calculated' || p.status == 'closed')
        .toList();
    if (payable.isNotEmpty) {
      payable.sort((a, b) => b.periodEnd.compareTo(a.periodEnd));
      return payable.first;
    }
    if (periods.isEmpty) return null;
    final sorted = List<PeriodOut>.from(periods)
      ..sort((a, b) => b.periodEnd.compareTo(a.periodEnd));
    return sorted.first;
  }

  void _populateForm(EmployeeModel emp) {
    fullNameController.text = emp.fullName;
    emailController.text = emp.email;
    phoneController.text = emp.phone;
    isActive.value = emp.isActive;
    defaultCurrencyCode.value = emp.defaultCurrencyCode;
  }

  void startEditing() => isEditing.value = true;

  void cancelEditing() {
    final emp = employee.value;
    if (emp != null) _populateForm(emp);
    isEditing.value = false;
  }

  String periodLabel(PeriodOut period) {
    return '${fmtPayrollDate(period.periodStart)} → ${fmtPayrollDate(period.periodEnd)} (${period.status})';
  }

  Future<void> saveDetails() async {
    if (fullNameController.text.trim().isEmpty) {
      _showError('Full name is required.');
      return;
    }

    try {
      isSaving.value = true;
      final updated = await _employeeRepository.updateEmployee(
        employeeId,
        EmployeeUpdateRequest(
          fullName: fullNameController.text.trim(),
          email: emailController.text.trim(),
          phone: phoneController.text.trim(),
          isActive: isActive.value,
          defaultCurrencyCode: defaultCurrencyCode.value,
        ),
      );
      employee.value = updated;
      isEditing.value = false;
      Get.snackbar(
        'Saved',
        'Employee details updated.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success,
        colorText: AppColors.textLight,
      );
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e));
    } catch (_) {
      _showError('Failed to save employee.');
    } finally {
      isSaving.value = false;
    }
  }

  void openManageRates() {
    PayrollModuleBinding.ensureDependencies();
    final future = Get.toNamed(AppRoutes.payrollEmployeeRates, arguments: employeeId);
    if (future != null) {
      future.then((_) => loadAll());
    }
  }

  void recordPayment() {
    final period = displayPeriod.value;
    if (period == null) {
      _showError('No payroll period available for payment.');
      return;
    }
    Get.toNamed(
      AppRoutes.paymentCreate,
      arguments: {'periodId': period.id, 'employeeId': employeeId},
    );
  }

  void viewBalance() {
    PayrollModuleBinding.ensureDependencies();
    Get.toNamed(AppRoutes.payrollEmployeeBalance, arguments: employeeId);
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
    fullNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.onClose();
  }
}
