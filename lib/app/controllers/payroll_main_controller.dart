import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../routes/app_navigation.dart';
import '../routes/app_routes.dart';
import '../routes/route_args.dart';

class PayrollMainController extends GetxController {
  void openPeriods() => Get.toNamed(AppRoutes.payrollPeriods);

  void openSummaryReport() => Get.toNamed(AppRoutes.payrollSummaryReport);

  Future<void> openEmployeeRates(BuildContext context) async {
    final picked = await _pickEmployee();
    if (picked != null) {
      Get.toNamed(AppRoutes.payrollEmployeeRates, arguments: picked);
    }
  }

  Future<void> openEmployeeBalance(BuildContext context) async {
    final picked = await _pickEmployee();
    if (picked != null) {
      Get.toNamed(AppRoutes.payrollEmployeeBalance, arguments: picked);
    }
  }

  Future<String?> _pickEmployee() async {
    final result = await pushNamedResult<EmployeePickerResult>(
      AppRoutes.employeePicker,
      arguments: const EmployeePickerArgs(title: 'Select Employee'),
    );
    return result?.employee.id;
  }
}
