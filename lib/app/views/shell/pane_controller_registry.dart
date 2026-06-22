import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../bindings/employee_module_binding.dart';
import '../../bindings/payroll_module_binding.dart';
import '../../controllers/employee_detail_controller.dart';
import '../../controllers/employee_rate_form_controller.dart';
import '../../controllers/payroll_period_detail_controller.dart';
import '../../data/models/payroll/period_out.dart';
import '../../data/repositories/payroll_repository.dart';
import '../../routes/route_args.dart';
import 'pane_tags.dart';

/// Registers pane-scoped GetX controllers for two-pane wide layouts.
abstract final class PaneControllerRegistry {
  PaneControllerRegistry._();

  static void ensureEmployeeDetail({
    required String employeeId,
    VoidCallback? onDeletedInPane,
  }) {
    EmployeeModuleBinding.ensureDependencies();
    PayrollModuleBinding.ensureDependencies();

    if (Get.isRegistered<EmployeeDetailController>(tag: PaneTags.employeeDetail)) {
      Get.delete<EmployeeDetailController>(tag: PaneTags.employeeDetail);
    }

    Get.put(
      EmployeeDetailController(
        employeeRepository: Get.find(),
        payrollRepository: Get.find<PayrollRepository>(),
        initialEmployeeId: employeeId,
        onDeletedInPane: onDeletedInPane,
      ),
      tag: PaneTags.employeeDetail,
    );
  }

  static void disposeEmployeeDetail() {
    if (Get.isRegistered<EmployeeDetailController>(tag: PaneTags.employeeDetail)) {
      Get.delete<EmployeeDetailController>(tag: PaneTags.employeeDetail);
    }
  }

  static void ensurePeriodDetail(PeriodOut period) {
    PayrollModuleBinding.ensureDependencies();

    if (Get.isRegistered<PayrollPeriodDetailController>(
      tag: PaneTags.periodDetail,
    )) {
      Get.delete<PayrollPeriodDetailController>(tag: PaneTags.periodDetail);
    }

    Get.put(
      PayrollPeriodDetailController(
        repository: Get.find<PayrollRepository>(),
        initialPeriod: period,
      ),
      tag: PaneTags.periodDetail,
    );
  }

  static void disposePeriodDetail() {
    if (Get.isRegistered<PayrollPeriodDetailController>(tag: PaneTags.periodDetail)) {
      Get.delete<PayrollPeriodDetailController>(tag: PaneTags.periodDetail);
    }
  }

  static void ensureRateForm({
    required EmployeeRateFormArgs args,
    VoidCallback? onSavedInPane,
  }) {
    PayrollModuleBinding.ensureDependencies();

    if (Get.isRegistered<EmployeeRateFormController>(tag: PaneTags.rateForm)) {
      Get.delete<EmployeeRateFormController>(tag: PaneTags.rateForm);
    }

    final controller = EmployeeRateFormController(repository: Get.find());
    controller.onSavedInPane = onSavedInPane;
    if (!controller.bindFromArgs(args)) {
      return;
    }

    Get.put(controller, tag: PaneTags.rateForm);
  }

  static void disposeRateForm() {
    if (Get.isRegistered<EmployeeRateFormController>(tag: PaneTags.rateForm)) {
      Get.delete<EmployeeRateFormController>(tag: PaneTags.rateForm);
    }
  }
}
