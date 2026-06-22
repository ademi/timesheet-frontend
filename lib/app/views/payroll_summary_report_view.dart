import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/payroll_summary_report_controller.dart';
import '../data/models/payroll/period_out.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/responsive/max_width_box.dart';
import 'widgets/app_back_button.dart';

class PayrollSummaryReportView extends GetView<PayrollSummaryReportController> {
  const PayrollSummaryReportView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: AppRoutes.payrollMain),
        title: const Text('Payroll Summary'),
        backgroundColor: AppColors.darkBrown,
      ),
      body: MaxWidthBox(
        maxWidth: Breakpoints.maxContent,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
            _buildFilters(context),
            const SizedBox(height: 12),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (controller.rows.isEmpty) {
                  return Center(
                    child: Text(
                      'No data.\nSelect filters and tap Load Report.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }
                return Column(
                  children: [
                    if (controller.source.value.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Chip(
                          label: Text('Source: ${controller.source.value}'),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Expanded(child: _buildTable()),
                  ],
                );
              }),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Obx(
            () => SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('By Period')),
                ButtonSegment(value: false, label: Text('By Date Range')),
              ],
              selected: {controller.usePeriodFilter.value},
              onSelectionChanged: (value) =>
                  controller.setFilterMode(value.first),
            ),
          ),
          const SizedBox(height: 12),
          Obx(() {
            if (controller.usePeriodFilter.value) {
              return DropdownButtonFormField<PeriodOut?>(
                value: controller.selectedPeriod.value,
                isExpanded: true,
                items: controller.periods
                    .map(
                      (period) => DropdownMenuItem<PeriodOut?>(
                        value: period,
                        child: Text(
                          '${controller.formatDate(period.periodStart)} → ${controller.formatDate(period.periodEnd)} (${period.status})',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => controller.selectedPeriod.value = value,
                decoration: const InputDecoration(labelText: 'Payroll Period'),
              );
            }
            return Row(
              children: [
                Expanded(
                  child: _DateSelector(
                    label: 'From',
                    value: controller.fromDate.value,
                    onTap: () => controller.setFromDate(context),
                    format: controller.formatDate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateSelector(
                    label: 'To',
                    value: controller.toDate.value,
                    onTap: () => controller.setToDate(context),
                    format: controller.formatDate,
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: controller.loadReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textLight,
              ),
              child: const Text('Load Report'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return DataTable2(
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
      rows: controller.rows
          .map(
            (row) => DataRow(
              cells: [
                DataCell(Text(row.fullName)),
                DataCell(Text('${row.regularMinutes}')),
                DataCell(Text('${row.overtimeMinutes}')),
                DataCell(Text('${row.nightMinutes}')),
                DataCell(Text('${row.weekendMinutes}')),
                DataCell(Text(row.amountDue.toStringAsFixed(2))),
              ],
            ),
          )
          .toList(),
    );
  }
}

class _DateSelector extends StatelessWidget {
  const _DateSelector({
    required this.label,
    required this.value,
    required this.onTap,
    required this.format,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final String Function(DateTime) format;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          value != null ? format(value!) : 'Select date',
          style: TextStyle(
            color: value != null ? AppColors.darkBrown : Colors.grey,
          ),
        ),
      ),
    );
  }
}
