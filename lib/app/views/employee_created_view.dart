import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../bindings/payroll_module_binding.dart';
import '../routes/app_routes.dart';
import '../routes/route_args.dart';
import '../themes/app_colors.dart';

class EmployeeCreatedView extends StatelessWidget {
  const EmployeeCreatedView({super.key});

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments;
    if (args is! EmployeeCreatedArgs) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Employee Created'),
          backgroundColor: AppColors.darkBrown,
        ),
        body: Center(
          child: TextButton(
            onPressed: Get.back,
            child: const Text('Go back'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Employee Created'),
        backgroundColor: AppColors.darkBrown,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Employee created successfully',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Would you like to set the initial payroll rate for this employee?',
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: () => Get.back(result: true),
              child: const Text('Skip for now'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                PayrollModuleBinding.ensureDependencies();
                Get.offNamed(
                  AppRoutes.payrollEmployeeRates,
                  arguments: args.employeeId,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Set payroll rate'),
            ),
          ],
        ),
      ),
    );
  }
}
