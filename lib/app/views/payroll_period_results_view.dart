import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/payroll_period_results_controller.dart';
import '../data/models/payroll/result_out.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';
import 'payroll_result_detail_view.dart';
import 'shell/two_pane.dart';
import 'widgets/app_back_button.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/responsive/max_width_box.dart';

class PayrollPeriodResultsView extends GetView<PayrollPeriodResultsController> {
  const PayrollPeriodResultsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: AppRoutes.payrollPeriods),
        title: const Text('Period Results'),
        backgroundColor: AppColors.darkBrown,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final twoPane = useTwoPaneLayout(constraints.maxWidth);

          return Obx(() {
            if (controller.isLoading.value) {
              return const Center(child: CircularProgressIndicator());
            }
            if (controller.results.isEmpty) {
              return const Center(child: Text('No results for this period.'));
            }

            if (!twoPane) {
              return MaxWidthBox(
                maxWidth: Breakpoints.maxContent,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildTable(useTwoPane: false),
                ),
              );
            }

            final selected = controller.selectedResult.value;
            return TwoPane(
              masterWidth: 520,
              master: Padding(
                padding: const EdgeInsets.all(8),
                child: _buildTable(useTwoPane: true),
              ),
              detail: selected == null
                  ? const PaneDetailPlaceholder(
                      message: 'Select a result to view details',
                      icon: Icons.receipt_long_rounded,
                    )
                  : PayrollResultDetailContent(result: selected),
            );
          });
        },
      ),
    );
  }

  Widget _buildTable({required bool useTwoPane}) {
    return DataTable2(
      columnSpacing: 12,
      horizontalMargin: 12,
      minWidth: useTwoPane ? 480 : 900,
      headingRowColor:
          WidgetStateProperty.all(AppColors.primary.withValues(alpha: 0.1)),
      columns: const [
        DataColumn2(label: Text('Employee'), size: ColumnSize.L),
        DataColumn2(label: Text('Regular'), size: ColumnSize.S),
        DataColumn2(label: Text('OT'), size: ColumnSize.S),
        DataColumn2(label: Text('Night'), size: ColumnSize.S),
        DataColumn2(label: Text('Weekend'), size: ColumnSize.S),
        DataColumn2(label: Text('Amount Due'), size: ColumnSize.S),
      ],
      rows: controller.results
          .map((result) => _buildRow(result, useTwoPane: useTwoPane))
          .toList(),
    );
  }

  DataRow _buildRow(ResultOut result, {required bool useTwoPane}) {
    final isSelected =
        useTwoPane && controller.selectedResult.value?.id == result.id;
    return DataRow(
      selected: isSelected,
      onSelectChanged: (_) => controller.selectResult(
        result,
        useTwoPane: useTwoPane,
      ),
      cells: [
        DataCell(Text(result.employeeName ?? result.employeeId)),
        DataCell(Text('${result.regularMinutes}')),
        DataCell(Text('${result.overtimeMinutes}')),
        DataCell(Text('${result.nightMinutes}')),
        DataCell(Text('${result.weekendMinutes}')),
        DataCell(Text(result.amountDue.toStringAsFixed(2))),
      ],
    );
  }
}
