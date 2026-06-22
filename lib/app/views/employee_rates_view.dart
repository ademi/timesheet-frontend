import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/employee_rates_controller.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';
import 'employee_rate_form_view.dart';
import 'shell/two_pane.dart';
import 'widgets/app_back_button.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/responsive/max_width_box.dart';

class EmployeeRatesView extends GetView<EmployeeRatesController> {
  const EmployeeRatesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: AppRoutes.payrollMain),
        title: const Text('Employee Rates'),
        backgroundColor: AppColors.darkBrown,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCreate(context),
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
            final showForm = controller.paneFormArgs.value != null;
            return TwoPane(
              masterWidth: 380,
              master: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 0),
                child: _buildRateList(useTwoPane: true),
              ),
              detail: showForm
                  ? const EmployeeRateFormPane()
                  : const PaneDetailPlaceholder(
                      message: 'Select a rate to edit, or tap + to create',
                      icon: Icons.payments_outlined,
                    ),
            );
          });
        },
      ),
    );
  }

  void _openCreate(BuildContext context) {
    final twoPane = useTwoPaneLayout(MediaQuery.sizeOf(context).width);
    controller.openCreateForm(useTwoPane: twoPane);
  }

  Widget _buildPhoneBody() {
    if (controller.isLoading.value && controller.rates.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.rates.isEmpty) {
      return const Center(child: Text('No rates for this employee yet.'));
    }
    return MaxWidthBox(
      maxWidth: Breakpoints.maxContent,
      child: _buildRateList(useTwoPane: false),
    );
  }

  Widget _buildRateList({required bool useTwoPane}) {
    if (controller.isLoading.value && controller.rates.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.rates.isEmpty) {
      return const Center(child: Text('No rates for this employee yet.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: controller.rates.length,
      itemBuilder: (context, index) {
        final rate = controller.rates[index];
        final toLabel = rate.effectiveTo != null
            ? controller.formatDate(rate.effectiveTo!)
            : 'ongoing';
        final isSelected = useTwoPane &&
            controller.paneFormArgs.value?.rate?.id == rate.id;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.10)
              : AppColors.cardBackground,
          child: ListTile(
            title: Text(
              '${controller.formatDate(rate.effectiveFrom)} → $toLabel',
            ),
            subtitle: Text(
              'Base: ${rate.baseRate} | Weekend: ${rate.weekendRate} | Night: ${rate.nightRate}',
            ),
            onTap: () => controller.openEditForm(rate, useTwoPane: useTwoPane),
          ),
        );
      },
    );
  }
}
