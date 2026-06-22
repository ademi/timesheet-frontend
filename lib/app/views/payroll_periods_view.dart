import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/payroll_periods_controller.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';
import 'shell/two_pane.dart';
import 'widgets/app_back_button.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/responsive/max_width_box.dart';
import 'payroll_period_detail_view.dart';

class PayrollPeriodsView extends GetView<PayrollPeriodsController> {
  const PayrollPeriodsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: AppRoutes.payrollMain),
        title: const Text('Payroll Periods'),
        backgroundColor: AppColors.darkBrown,
        actions: [
          IconButton(
            onPressed: controller.openSettings,
            icon: const Icon(Icons.settings),
            tooltip: 'Payroll Settings',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => controller.openCreatePeriodSheet(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final twoPane = useTwoPaneLayout(constraints.maxWidth);

          if (!twoPane) {
            return Obx(() => _buildPhoneBody());
          }

          return Obx(() {
            final selected = controller.selectedPeriod.value;
            return TwoPane(
              masterWidth: 380,
              master: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 0),
                child: _buildPeriodList(useTwoPane: true),
              ),
              detail: selected == null
                  ? const PaneDetailPlaceholder(
                      message: 'Select a payroll period',
                      icon: Icons.date_range_rounded,
                    )
                  : const PayrollPeriodDetailPane(),
            );
          });
        },
      ),
    );
  }

  Widget _buildPhoneBody() {
    if (controller.isLoading.value && controller.periods.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.periods.isEmpty) {
      return const Center(child: Text('No payroll periods yet.'));
    }
    return MaxWidthBox(
      maxWidth: Breakpoints.maxContent,
      child: _buildPeriodList(useTwoPane: false),
    );
  }

  Widget _buildPeriodList({required bool useTwoPane}) {
    if (controller.isLoading.value && controller.periods.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.periods.isEmpty) {
      return const Center(child: Text('No payroll periods yet.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: controller.periods.length,
      itemBuilder: (context, index) {
        final period = controller.periods[index];
        final isSelected =
            useTwoPane && controller.selectedPeriod.value?.id == period.id;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.10)
              : AppColors.cardBackground,
          child: ListTile(
            title: Text(
              '${controller.formatDate(period.periodStart)} → ${controller.formatDate(period.periodEnd)}',
            ),
            subtitle: Text('Status: ${period.status}'),
            trailing: Chip(
              label: Text(
                period.status,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              backgroundColor: controller.statusColor(period.status),
            ),
            onTap: () => controller.openPeriodDetail(period, useTwoPane: useTwoPane),
          ),
        );
      },
    );
  }
}
