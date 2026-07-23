import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/employee_portal_controller.dart';
import '../data/models/scheduling/scheduling_date_utils.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';
import 'widgets/app_back_button.dart';

String _fmtDt(DateTime d) {
  final local = d.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '${fmtSchedulingDate(local)} $h:$m';
}

class EmployeeMyHoursView extends GetView<EmployeeMyHoursController> {
  const EmployeeMyHoursView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: AppRoutes.employeePortal),
        title: const Text('My Hours'),
        backgroundColor: AppColors.darkBrown,
        actions: [
          IconButton(
            onPressed: controller.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.entries.isEmpty) {
          return const Center(child: Text('No time entries this month.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: controller.entries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final e = controller.entries[i];
            final out = e.clockOutAt == null ? 'Open' : _fmtDt(e.clockOutAt!);
            return ListTile(
              tileColor: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text(_fmtDt(e.clockInAt)),
              subtitle: Text('Out: $out · ${e.status}'),
            );
          },
        );
      }),
    );
  }
}

class EmployeeMyScheduleView extends GetView<EmployeeMyScheduleController> {
  const EmployeeMyScheduleView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: AppRoutes.employeePortal),
        title: const Text('My Schedule'),
        backgroundColor: AppColors.darkBrown,
        actions: [
          IconButton(
            onPressed: controller.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.assignments.isEmpty) {
          return const Center(
            child: Text('No assignments in the next two weeks.'),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: controller.assignments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final a = controller.assignments[i];
            final label =
                a.isDayOff ? 'Day off' : (a.templateName ?? 'Assigned');
            return ListTile(
              tileColor: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text(fmtSchedulingDate(a.workDate)),
              subtitle: Text(label),
            );
          },
        );
      }),
    );
  }
}
