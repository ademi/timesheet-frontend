import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/payments_report_controller.dart';
import '../data/models/attendance/employee_model.dart';
import '../data/models/payroll/period_out.dart';
import '../themes/app_colors.dart';

class PaymentsReportView extends GetView<PaymentsReportController> {
  const PaymentsReportView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Payments Report'),
        backgroundColor: AppColors.darkBrown,
        actions: [
          Obx(
            () => IconButton(
              tooltip: 'Export to Excel',
              onPressed: controller.rows.isEmpty ? null : controller.exportToExcel,
              icon: Icon(
                Icons.file_download_outlined,
                color: controller.rows.isEmpty
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
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
                      'No data available.\nSelect filters and tap "Generate Report".',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }
                return _buildTable();
              }),
            ),
          ],
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
          Row(
            children: [
              Expanded(child: _DateSelector(label: 'From', onTap: () => controller.setFromDate(context), value: controller.fromDate)),
              const SizedBox(width: 10),
              Expanded(child: _DateSelector(label: 'To', onTap: () => controller.setToDate(context), value: controller.toDate)),
            ],
          ),
          const SizedBox(height: 10),
          Obx(
            () => DropdownButtonFormField<EmployeeModel?>(
              value: controller.selectedEmployee.value,
              isExpanded: true,
              items: [
                const DropdownMenuItem<EmployeeModel?>(
                  value: null,
                  child: Text('All Employees'),
                ),
                ...controller.employees.map(
                  (employee) => DropdownMenuItem<EmployeeModel?>(
                    value: employee,
                    child: Text('${employee.fullName} (${employee.employeeCode})'),
                  ),
                ),
              ],
              onChanged: (value) => controller.selectedEmployee.value = value,
              decoration: const InputDecoration(
                labelText: 'Employee (Optional)',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Obx(
            () => DropdownButtonFormField<PeriodOut?>(
              value: controller.selectedPeriod.value,
              isExpanded: true,
              items: [
                const DropdownMenuItem<PeriodOut?>(
                  value: null,
                  child: Text('All Periods'),
                ),
                ...controller.periods.map(
                  (period) => DropdownMenuItem<PeriodOut?>(
                    value: period,
                    child: Text(controller.periodLabel(period)),
                  ),
                ),
              ],
              onChanged: (value) => controller.selectedPeriod.value = value,
              decoration: const InputDecoration(
                labelText: 'Payroll Period (Optional)',
                prefixIcon: Icon(Icons.date_range_rounded),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('payments_report_generate_button'),
              onPressed: controller.fetchReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.analytics_rounded),
              label: const Text('Generate Report'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return DataTable2(
      key: const Key('payments_report_table'),
      minWidth: 960,
      columnSpacing: 12,
      horizontalMargin: 12,
      headingRowColor: WidgetStateProperty.all(AppColors.primary.withValues(alpha: 0.1)),
      columns: const [
        DataColumn2(label: Text('Name/Code'), size: ColumnSize.L, fixedWidth: 200),
        DataColumn2(label: Text('Period'), size: ColumnSize.M, fixedWidth: 180),
        DataColumn2(label: Text('Payment Date'), size: ColumnSize.M, fixedWidth: 120),
        DataColumn2(label: Text('Amount'), size: ColumnSize.S, numeric: true),
        DataColumn2(label: Text('Currency'), size: ColumnSize.S),
        DataColumn2(label: Text('Method'), size: ColumnSize.M, fixedWidth: 160),
        DataColumn2(label: Text('Reference'), size: ColumnSize.M, fixedWidth: 170),
      ],
      rows: controller.rows
          .map(
            (row) => DataRow(
              cells: [
                DataCell(Text('${row.employeeName}\n${row.employeeCode}')),
                DataCell(
                  Text(
                    row.periodStart != null && row.periodEnd != null
                        ? '${row.periodStart} → ${row.periodEnd}'
                        : '-',
                  ),
                ),
                DataCell(Text(row.paymentDate)),
                DataCell(Text(row.amountPaid.toStringAsFixed(2))),
                DataCell(Text(row.currencyCode)),
                DataCell(Text(row.paymentMethod ?? '-')),
                DataCell(Text(row.referenceNo ?? '-')),
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
    required this.onTap,
    required this.value,
  });

  final String label;
  final VoidCallback onTap;
  final Rx<DateTime?> value;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.calendar_month_rounded),
          ),
          child: Text(
            value.value == null
                ? 'Select date'
                : '${value.value!.year}-${value.value!.month.toString().padLeft(2, '0')}-${value.value!.day.toString().padLeft(2, '0')}',
          ),
        ),
      ),
    );
  }
}
