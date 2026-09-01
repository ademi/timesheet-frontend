import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/themes/app_colors.dart';
import '../../models/support_plan_specialist_entry.dart';

/// Specialist block with always-visible detail fields for dynamic support plan.
class SupportPlanSpecialistSection extends StatelessWidget {
  const SupportPlanSpecialistSection({
    super.key,
    required this.entry,
    required this.enabled,
  });

  final SupportPlanSpecialistEntry entry;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      entry.revision.value;
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primaryLight),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                entry.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              if (entry.isOther) ...[
                TextField(
                  controller: entry.customLabelCtrl,
                  enabled: enabled,
                  onChanged: enabled ? (_) => entry.revision.value++ : null,
                  decoration: const InputDecoration(
                    labelText: 'Specialist type',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: entry.fields.nameCtrl,
                enabled: enabled,
                decoration: InputDecoration(
                  labelText: entry.nameFieldLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: entry.fields.companyCtrl,
                enabled: enabled,
                decoration: const InputDecoration(
                  labelText: 'Company name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: entry.fields.abnAcnCtrl,
                enabled: enabled,
                decoration: const InputDecoration(
                  labelText: 'ACN/ABN',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: entry.fields.orgIdCtrl,
                enabled: enabled,
                decoration: const InputDecoration(
                  labelText: 'Organisation ID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: entry.fields.phoneCtrl,
                enabled: enabled,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: entry.fields.emailCtrl,
                enabled: enabled,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: entry.fields.addressCtrl,
                enabled: enabled,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
