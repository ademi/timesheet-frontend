import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/client_onboarding_controller.dart';

class OnboardingFundingStep extends StatelessWidget {
  const OnboardingFundingStep({super.key, required this.controller});

  final ClientOnboardingController controller;

  static const planTypes = <String, String>{
    'ndia': 'NDIA managed',
    'plan_managed': 'Plan managed',
    'self_managed': 'Self managed',
  };

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final planType = controller.planManagementType.value;
      final isPlanManaged = planType == 'plan_managed';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Funding',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: planType,
            decoration: const InputDecoration(
              labelText: 'Plan management type *',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Select'),
              ),
              for (final e in planTypes.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => controller.planManagementType.value = v,
          ),
          if (isPlanManaged) ...[
            const SizedBox(height: 12),
            TextField(
              controller: controller.planManagerNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Plan manager name *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.planManagerPhoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Plan manager phone',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.planManagerEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Plan manager email',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Plan dates (optional)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              controller.planStartDate.value == null
                  ? 'Plan start date'
                  : 'Start: ${_fmt(controller.planStartDate.value!)}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: controller.planStartDate.value ?? DateTime.now(),
                firstDate: DateTime(2013),
                lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
              );
              if (picked != null) controller.planStartDate.value = picked;
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              controller.planEndDate.value == null
                  ? 'Plan end date'
                  : 'End: ${_fmt(controller.planEndDate.value!)}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: controller.planEndDate.value ??
                    DateTime.now().add(const Duration(days: 365)),
                firstDate: DateTime(2013),
                lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
              );
              if (picked != null) controller.planEndDate.value = picked;
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'Budgets (optional)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller.budgetCoreCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Core support budget',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.budgetCbCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Capacity building budget',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.budgetCapitalCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Capital support budget',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.fundingNotToExceedCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Funding not to exceed',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Support coordinator (optional)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller.scNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.scPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.scEmailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      );
    });
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';
}
