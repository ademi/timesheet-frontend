import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/client_onboarding_controller.dart';
import 'support_plan_professional_section.dart';

class OnboardingSupportPlanStep extends StatelessWidget {
  const OnboardingSupportPlanStep({super.key, required this.controller});

  final ClientOnboardingController controller;

  static const planTypes = <String, String>{
    'ndia': 'NDIA managed',
    'plan_managed': 'Plan managed',
    'self_managed': 'Self managed',
  };

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final enabled = !controller.isSaving.value;
      final planType = controller.planManagementType.value;
      final isPlanManaged = planType == 'plan_managed';
      final ndisPending = controller.ndisPdfAttachment.pending.value;
      final ndisOnFile = controller.ndisPdfAttachment.hasAttachment;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Support Plan',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.ndisCtrl,
            enabled: enabled,
            decoration: InputDecoration(
              labelText: 'NDIS number *',
              border: const OutlineInputBorder(),
              errorText: controller.ndisFieldError.value,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'NDIS PDF plan',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: enabled ? controller.pickNdisPlanPdf : null,
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(
              ndisPending != null || ndisOnFile
                  ? 'Replace NDIS plan PDF'
                  : 'Attach NDIS plan PDF',
            ),
          ),
          if (controller.ndisPdfAttachment.existingDocumentLabel.value !=
                  null &&
              ndisPending == null) ...[
            const SizedBox(height: 6),
            Text(
              controller.ndisPdfAttachment.existingDocumentLabel.value!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (ndisPending != null) ...[
            const SizedBox(height: 6),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.insert_drive_file_outlined, size: 20),
              title: Text(
                ndisPending.name,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: enabled ? controller.clearNdisPlanPdfPending : null,
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: controller.supportPlanOtherCtrl,
            enabled: enabled,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Other',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
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
            onChanged: enabled ? (v) => controller.planManagementType.value = v : null,
          ),
          if (isPlanManaged) ...[
            const SizedBox(height: 16),
            const Text(
              'Plan manager details',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller.planManagerNameCtrl,
              enabled: enabled,
              decoration: const InputDecoration(
                labelText: 'Plan manager name *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.planManagerCompanyCtrl,
              enabled: enabled,
              decoration: const InputDecoration(
                labelText: 'Company name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.planManagerAbnAcnCtrl,
              enabled: enabled,
              decoration: const InputDecoration(
                labelText: 'ACN/ABN',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.planManagerOrgIdCtrl,
              enabled: enabled,
              decoration: const InputDecoration(
                labelText: 'Organisation ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.planManagerPhoneCtrl,
              enabled: enabled,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.planManagerEmailCtrl,
              enabled: enabled,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.planManagerAddressCtrl,
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
            onTap: enabled
                ? () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          controller.planStartDate.value ?? DateTime.now(),
                      firstDate: DateTime(2013),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (picked != null) controller.onPlanStartPicked(picked);
                  }
                : null,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              controller.planEndDate.value == null
                  ? 'Plan end date'
                  : 'End: ${_fmt(controller.planEndDate.value!)}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: enabled
                ? () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: controller.planEndDate.value ??
                          DateTime.now().add(const Duration(days: 365)),
                      firstDate: DateTime(2013),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (picked != null) controller.planEndDate.value = picked;
                  }
                : null,
          ),
          const SizedBox(height: 8),
          const Text(
            'Budgets (optional)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller.budgetCoreCtrl,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Core support budget',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.budgetCbCtrl,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Capacity building budget',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.budgetCapitalCtrl,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Capital support budget',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SupportPlanProfessionalSection(
            title: 'Support coordinator (optional)',
            nameLabel: 'SC name',
            fields: controller.supportCoordinator,
            expanded: controller.supportCoordinatorExpanded,
            enabled: enabled,
          ),
          SupportPlanProfessionalSection(
            title: 'Behavioural therapist (optional)',
            nameLabel: 'Specialist name',
            fields: controller.behaviouralTherapist,
            expanded: controller.behaviouralTherapistExpanded,
            enabled: enabled,
          ),
          SupportPlanProfessionalSection(
            title: 'Speech therapist (optional)',
            nameLabel: 'Specialist name',
            fields: controller.speechTherapist,
            expanded: controller.speechTherapistExpanded,
            enabled: enabled,
          ),
          SupportPlanProfessionalSection(
            title: 'Occupational therapist (optional)',
            nameLabel: 'Specialist name',
            fields: controller.occupationalTherapist,
            expanded: controller.occupationalTherapistExpanded,
            enabled: enabled,
          ),
          SupportPlanProfessionalSection(
            title: 'Physiotherapist (optional)',
            nameLabel: 'Specialist name',
            fields: controller.physiotherapist,
            expanded: controller.physiotherapistExpanded,
            enabled: enabled,
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
