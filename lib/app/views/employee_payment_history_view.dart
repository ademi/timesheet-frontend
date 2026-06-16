import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/employee_payment_history_controller.dart';
import '../data/models/attendance/employee_model.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';
import 'widgets/app_back_button.dart';

class EmployeePaymentHistoryView extends GetView<EmployeePaymentHistoryController> {
  const EmployeePaymentHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: AppRoutes.paymentMain),
        title: const Text('Employee Payment History'),
        backgroundColor: AppColors.darkBrown,
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Obx(
              () => DropdownButtonFormField<EmployeeModel>(
                value: controller.selectedEmployee.value,
                isExpanded: true,
                items: controller.employees
                    .map(
                      (employee) => DropdownMenuItem<EmployeeModel>(
                        value: employee,
                        child: Text('${employee.fullName} (${employee.employeeCode})'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => controller.selectedEmployee.value = value,
                decoration: const InputDecoration(
                  labelText: 'Employee',
                  prefixIcon: Icon(Icons.person_search_rounded),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: controller.fetchHistory,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Load History'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value || controller.isLoadingEmployees.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                final error = controller.errorMessage.value;
                if (error != null && error.isNotEmpty) {
                  return Center(
                    child: Text(
                      error,
                      style: const TextStyle(color: AppColors.error),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                if (controller.payments.isEmpty) {
                  return const Center(child: Text('No payments found for this employee.'));
                }
                return ListView.separated(
                  itemBuilder: (context, index) {
                    final payment = controller.payments[index];
                    return Card(
                      child: ListTile(
                        title: Text(
                          '${payment.amountPaid.toStringAsFixed(2)} ${payment.currencyCode}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Date: ${payment.paymentDate}\n'
                          'Period: ${payment.periodId ?? '—'}\n'
                          'Method: ${payment.paymentMethod ?? '-'}\n'
                          'Reference: ${payment.referenceNo ?? '-'}',
                        ),
                        leading: const Icon(Icons.account_balance_wallet_outlined),
                      ),
                    );
                  },
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemCount: controller.payments.length,
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
