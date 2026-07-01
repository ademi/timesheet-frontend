import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/responsive/breakpoints.dart';
import '../../core/responsive/max_width_box.dart';
import '../controllers/shift_schedule_controller.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';
import 'widgets/app_back_button.dart';
import 'widgets/shift_schedule_body.dart';
import 'widgets/shift_schedule_fab.dart';

class ShiftScheduleView extends GetView<ShiftScheduleController> {
  const ShiftScheduleView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: AppRoutes.adminPanel),
        title: const Text('Shift Schedule'),
        backgroundColor: AppColors.darkBrown,
        actions: [_BranchMenu()],
      ),
      floatingActionButton: ShiftScheduleFab(),
      body: MaxWidthBox(
        maxWidth: Breakpoints.maxContent,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: ShiftScheduleBody(),
        ),
      ),
    );
  }
}

class _BranchMenu extends GetView<ShiftScheduleController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final branches = controller.branches;
      final selectedId = controller.selectedBranchId.value;
      if (branches.isEmpty) return const SizedBox.shrink();

      return PopupMenuButton<String>(
        tooltip: 'Branch',
        icon: const Icon(Icons.storefront_rounded, color: AppColors.primary),
        onSelected: controller.selectBranch,
        itemBuilder: (context) => branches
            .map(
              (b) => PopupMenuItem<String>(
                value: b.id,
                child: Text(
                  b.name,
                  style: TextStyle(
                    fontWeight:
                        b.id == selectedId ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            )
            .toList(),
      );
    });
  }
}
