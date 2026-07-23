import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/responsive/breakpoints.dart';
import '../../core/responsive/max_width_box.dart';
import '../../core/services/token_storage.dart';
import '../constants/app_permissions.dart';
import '../controllers/auth_controller.dart';
import '../controllers/employee_portal_controller.dart';
import '../themes/app_colors.dart';
import '../widgets/admin_hub_card.dart';

class EmployeePortalView extends GetView<EmployeePortalController> {
  const EmployeePortalView({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = Get.find<TokenStorage>();
    final auth = Get.find<AuthController>();
    final cards = <Widget>[
      if (storage.hasPermission(AppPermissions.attendanceViewOwn))
        AdminHubCard(
          icon: Icons.schedule_rounded,
          title: 'My Hours',
          subtitle: 'Review your recent clock-in history',
          onTap: controller.openMyHours,
        ),
      if (storage.hasPermission(AppPermissions.schedulingViewOwn) ||
          storage.hasPermission(AppPermissions.schedulingRead))
        AdminHubCard(
          icon: Icons.calendar_today_rounded,
          title: 'My Schedule',
          subtitle: 'See your upcoming shifts',
          onTap: controller.openMySchedule,
        ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Employee'),
        backgroundColor: AppColors.darkBrown,
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: auth.logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: MaxWidthBox(
          maxWidth: Breakpoints.formMaxWidth,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: cards.isEmpty
                ? const Center(
                    child: Text('No employee self-service permissions on this account.'),
                  )
                : ListView.separated(
                    itemCount: cards.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => cards[i],
                  ),
          ),
        ),
      ),
    );
  }
}
