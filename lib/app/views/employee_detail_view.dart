import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/employee_detail_controller.dart';
import '../core/constants/payment_currencies.dart';
import '../data/models/payroll/payroll_date_utils.dart';
import '../themes/app_colors.dart';

class EmployeeDetailView extends GetView<EmployeeDetailController> {
  const EmployeeDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Obx(
          () => Text(controller.employee.value?.fullName ?? 'Employee'),
        ),
        backgroundColor: AppColors.darkBrown,
        actions: [
          IconButton(
            onPressed: controller.loadAll,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.employee.value == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: controller.loadAll,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _DetailsSection(controller: controller),
              const SizedBox(height: 16),
              _PayrollSection(controller: controller),
              const SizedBox(height: 16),
              _RatesSection(controller: controller),
              const SizedBox(height: 16),
              _AttendanceSection(controller: controller),
              const SizedBox(height: 24),
            ],
          ),
        );
      }),
    );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({required this.controller});

  final EmployeeDetailController controller;

  @override
  Widget build(BuildContext context) {
    final emp = controller.employee.value;
    return Obx(() {
      final editing = controller.isEditing.value;
      return _SectionCard(
        title: 'Employee Details',
        icon: Icons.person_outline_rounded,
        trailing: editing
            ? null
            : TextButton.icon(
                onPressed: controller.startEditing,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (emp != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Code: ${emp.employeeCode}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ),
            TextField(
              controller: controller.fullNameController,
              readOnly: !editing,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.emailController,
              readOnly: !editing,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.phoneController,
              readOnly: !editing,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            if (editing) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: controller.defaultCurrencyCode.value,
                decoration: const InputDecoration(
                  labelText: 'Default Payment Currency',
                  prefixIcon: Icon(Icons.currency_exchange),
                ),
                items: PaymentCurrencies.supported
                    .map(
                      (code) => DropdownMenuItem(
                        value: code,
                        child: Text(code),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) controller.defaultCurrencyCode.value = value;
                },
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: controller.isActive.value,
              activeThumbColor: AppColors.primary,
              onChanged: editing ? (v) => controller.isActive.value = v : null,
            ),
            if (editing) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: controller.isSaving.value ? null : controller.cancelEditing,
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: controller.isSaving.value ? null : controller.saveDetails,
                      icon: controller.isSaving.value
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(controller.isSaving.value ? 'Saving...' : 'Save'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textLight,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    });
  }
}

class _PayrollSection extends StatelessWidget {
  const _PayrollSection({required this.controller});

  final EmployeeDetailController controller;

  @override
  Widget build(BuildContext context) {
    final period = controller.displayPeriod.value;
    final result = controller.periodResult.value;
    final balance = controller.balance.value;

    return _SectionCard(
      title: 'Payroll',
      icon: Icons.receipt_long_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (period == null)
            Text('No payroll period configured.', style: TextStyle(color: Colors.grey.shade600))
          else ...[
            Text(
              'Period: ${controller.periodLabel(period)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (result != null) ...[
              const SizedBox(height: 10),
              _MetricRow(
                label: 'Amount due',
                value: result.amountDue.toStringAsFixed(2),
              ),
              _MetricRow(label: 'Regular mins', value: '${result.regularMinutes}'),
              _MetricRow(label: 'Overtime mins', value: '${result.overtimeMinutes}'),
            ] else if (period.status == 'open')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Period not calculated yet — attendance shown below.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
          ],
          if (balance != null) ...[
            const Divider(height: 24),
            _MetricRow(label: 'Total owed', value: balance.totalOwed.toStringAsFixed(2)),
            _MetricRow(label: 'Total paid', value: balance.totalPaid.toStringAsFixed(2)),
            _MetricRow(
              label: 'Outstanding',
              value: balance.outstanding.toStringAsFixed(2),
              highlight: balance.outstanding > 0,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: controller.viewBalance,
                  icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                  label: const Text('Balance'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: period == null ? null : controller.recordPayment,
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('Pay'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textLight,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RatesSection extends StatelessWidget {
  const _RatesSection({required this.controller});

  final EmployeeDetailController controller;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Pay Rates',
      icon: Icons.payments_rounded,
      trailing: TextButton(
        onPressed: controller.openManageRates,
        child: const Text('Manage'),
      ),
      child: Obx(() {
        if (controller.rates.isEmpty) {
          return Text(
            'No pay rates configured.',
            style: TextStyle(color: Colors.grey.shade600),
          );
        }
        return Column(
          children: controller.rates.take(3).map((rate) {
            final to = rate.effectiveTo != null
                ? fmtPayrollDate(rate.effectiveTo!)
                : 'ongoing';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${fmtPayrollDate(rate.effectiveFrom)} → $to',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  Text(
                    'Base ${rate.baseRate}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      }),
    );
  }
}

class _AttendanceSection extends StatelessWidget {
  const _AttendanceSection({required this.controller});

  final EmployeeDetailController controller;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Attendance',
      icon: Icons.schedule_rounded,
      child: Obx(() {
        final period = controller.displayPeriod.value;
        if (period == null) {
          return Text('Select a payroll period to view attendance.',
              style: TextStyle(color: Colors.grey.shade600));
        }
        if (controller.timeEntries.isEmpty) {
          return Text(
            'No time entries in ${controller.periodLabel(period)}.',
            style: TextStyle(color: Colors.grey.shade600),
          );
        }
        return Column(
          children: controller.timeEntries.take(20).map((entry) {
            final out = entry.clockOutAt != null
                ? _formatDateTime(entry.clockOutAt!)
                : '—';
            return ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(_formatDateTime(entry.clockInAt),
                  style: const TextStyle(fontSize: 13)),
              subtitle: Text('Out: $out · ${entry.status}'),
              leading: Icon(
                entry.status == 'closed' ? Icons.check_circle_outline : Icons.pending_outlined,
                color: AppColors.primary,
                size: 20,
              ),
            );
          }).toList(),
        );
      }),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkBrown,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime dt) {
  final local = dt.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final h = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $h:$min';
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: highlight ? AppColors.error : AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
