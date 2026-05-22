import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/payroll_period_results_controller.dart';
import '../data/models/payroll/result_out.dart';
import '../themes/app_colors.dart';

class PayrollPeriodResultsView extends GetView<PayrollPeriodResultsController> {
  const PayrollPeriodResultsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
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
      onSelectChanged: (_) => _showDetailSheet(context, result),
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

  void _showDetailSheet(BuildContext context, ResultOut result) {
    Get.bottomSheet(
      Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                result.employeeName ?? result.employeeId,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text('Rate Snapshot', style: TextStyle(fontWeight: FontWeight.w600)),
              ...result.rateSnapshot.entries.map(
                (e) => Text('${e.key}: ${e.value}'),
              ),
              const SizedBox(height: 12),
              const Text('Calc Snapshot', style: TextStyle(fontWeight: FontWeight.w600)),
              ...result.calcSnapshot.entries.map(
                (e) => Text('${e.key}: ${e.value}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
