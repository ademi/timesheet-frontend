import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/payroll_settings_controller.dart';
import '../data/models/payroll/payroll_settings.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';
import 'widgets/app_back_button.dart';

class PayrollSettingsView extends GetView<PayrollSettingsController> {
  const PayrollSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: AppRoutes.payrollMain),
        title: const Text('Payroll Settings'),
        backgroundColor: AppColors.darkBrown,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Section(
              title: 'Schedule',
              child: Column(
                children: [
                  Obx(
                    () => DropdownButtonFormField<PayrollFrequency>(
                      value: controller.frequency.value,
                      decoration: const InputDecoration(
                        labelText: 'Payroll frequency',
                      ),
                      items:
                          PayrollFrequency.values
                              .map(
                                (frequency) => DropdownMenuItem(
                                  value: frequency,
                                  child: Text(frequency.label),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        if (value != null) controller.setFrequency(value);
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  Obx(() => _buildFrequencyOptions(context)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Creation Defaults',
              child: Column(
                children: [
                  Obx(
                    () => DropdownButtonFormField<PayrollDefaultCreationOption>(
                      value: controller.defaultCreationOption.value,
                      decoration: const InputDecoration(
                        labelText: 'Default creation option',
                      ),
                      items:
                          PayrollDefaultCreationOption.values
                              .map(
                                (option) => DropdownMenuItem(
                                  value: option,
                                  child: Text(option.label),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          controller.defaultCreationOption.value = value;
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Obx(
                    () => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Prevent overlapping periods'),
                      subtitle: const Text(
                        'Checks existing periods before creating a new one.',
                      ),
                      value: controller.preventOverlappingPeriods.value,
                      activeColor: AppColors.primary,
                      onChanged:
                          (value) =>
                              controller.preventOverlappingPeriods.value =
                                  value,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Obx(
              () => ElevatedButton(
                onPressed: controller.isSaving.value ? null : controller.save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textLight,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child:
                    controller.isSaving.value
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Text(
                          controller.hasExistingSettings.value
                              ? 'Save Settings'
                              : 'Save and Create First Period',
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencyOptions(BuildContext context) {
    switch (controller.frequency.value) {
      case PayrollFrequency.weekly:
        return _WeekdayDropdown(
          label: 'Week starts on',
          value: controller.weekStartDay.value,
          onChanged: (value) => controller.weekStartDay.value = value,
        );
      case PayrollFrequency.biweekly:
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('First known period start date'),
          subtitle: Text(
            controller.biweeklyAnchorDate.value == null
                ? 'Tap to select'
                : controller.formatDate(controller.biweeklyAnchorDate.value!),
          ),
          trailing: const Icon(Icons.calendar_today),
          onTap: () => controller.pickBiweeklyAnchorDate(context),
        );
      case PayrollFrequency.monthly:
        return DropdownButtonFormField<int>(
          value: controller.monthlyStartDay.value,
          decoration: const InputDecoration(
            labelText: 'Monthly period starts on day',
          ),
          items: List.generate(31, (index) {
            final day = index + 1;
            return DropdownMenuItem(value: day, child: Text('$day'));
          }),
          onChanged: (value) {
            if (value != null) controller.monthlyStartDay.value = value;
          },
        );
      case PayrollFrequency.custom:
        return Text(
          'Custom keeps the manual date range picker available when creating periods.',
          style: TextStyle(color: Colors.grey.shade700),
        );
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.darkBrown,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _WeekdayDropdown extends StatelessWidget {
  const _WeekdayDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const weekdays = [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    ];

    return DropdownButtonFormField<int>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items:
          weekdays
              .map(
                (weekday) => DropdownMenuItem(
                  value: weekday,
                  child: Text(payrollWeekdayLabel(weekday)),
                ),
              )
              .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}
