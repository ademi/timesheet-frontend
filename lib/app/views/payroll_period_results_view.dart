import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/payroll_period_results_controller.dart';
import '../data/models/payroll/result_out.dart';
import '../routes/app_routes.dart';
import '../routes/route_args.dart';
import '../themes/app_colors.dart';
import 'widgets/app_back_button.dart';

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
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.results.isEmpty) {
          return const Center(child: Text('No results for this period.'));
        }
        return Padding(
          padding: const EdgeInsets.all(12),
          child: DataTable2(
            columnSpacing: 12,
            horizontalMargin: 12,
            minWidth: 900,
            columns: const [
              DataColumn2(label: Text('Employee'), size: ColumnSize.L),
              DataColumn2(label: Text('Regular'), size: ColumnSize.S),
              DataColumn2(label: Text('OT'), size: ColumnSize.S),
              DataColumn2(label: Text('Night'), size: ColumnSize.S),
              DataColumn2(label: Text('Weekend'), size: ColumnSize.S),
              DataColumn2(label: Text('Amount Due'), size: ColumnSize.S),
            ],
            rows: controller.results
                .map((result) => _buildRow(context, result))
                .toList(),
          ),
        );
      }),
    );
  }

  DataRow _buildRow(BuildContext context, ResultOut result) {
    return DataRow(
      onSelectChanged: (_) => _openResultDetail(result),
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

  void _openResultDetail(ResultOut result) {
    Get.toNamed(
      AppRoutes.payrollPeriodResultDetail,
      arguments: PayrollResultDetailArgs(result: result),
    );
  }
}
