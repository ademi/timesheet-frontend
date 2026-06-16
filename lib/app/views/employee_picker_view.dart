import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/employee_picker_controller.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';
import 'widgets/app_back_button.dart';

class EmployeePickerView extends GetView<EmployeePickerController> {
  const EmployeePickerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: AppRoutes.adminPanel),
        title: Text(controller.title),
        backgroundColor: AppColors.darkBrown,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: controller.searchController,
              onChanged: controller.filterEmployees,
              decoration: const InputDecoration(
                hintText: 'Search by name or code',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (controller.filteredEmployees.isEmpty) {
                return const Center(child: Text('No employees found'));
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: controller.filteredEmployees.length,
                separatorBuilder: (_, _) => const Divider(height: 0),
                itemBuilder: (context, index) {
                  final employee = controller.filteredEmployees[index];
                  return ListTile(
                    title: Text(employee.fullName),
                    subtitle: Text(employee.employeeCode),
                    onTap: () => controller.selectEmployee(employee),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
