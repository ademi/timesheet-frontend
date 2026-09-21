import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../shared/widgets/app_date_field.dart';
import '../../../../shared/widgets/app_file_field.dart';
import '../../controllers/client_onboarding_controller.dart';

class OnboardingNdisStep extends StatelessWidget {
  const OnboardingNdisStep({super.key, required this.controller});

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
            'NDIS',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Optional for day-one — you can add plan details later.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.ndisCtrl,
            enabled: enabled,
            decoration: InputDecoration(
              labelText: 'NDIS number',
              border: const OutlineInputBorder(),
              errorText: controller.ndisFieldError.value,
            ),
          ),
          const SizedBox(height: 12),
          AppFileField(
            label: 'NDIS plan PDF',
            fileName:
                ndisPending?.name ??
                controller.ndisPdfAttachment.existingDocumentLabel.value ??
                (ndisOnFile ? 'Document on file' : null),
            enabled: enabled,
            onPick: controller.pickNdisPlanPdf,
            onClear:
                ndisPending != null && enabled
                    ? controller.clearNdisPlanPdfPending
                    : null,
            pickLabel:
                ndisPending != null || ndisOnFile
                    ? 'Replace file'
                    : 'Choose file',
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: planType,
            decoration: const InputDecoration(
              labelText: 'Plan management type',
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
            onChanged:
                enabled ? (v) => controller.planManagementType.value = v : null,
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
          const SizedBox(height: 12),
          AppDateField(
            label: 'Plan start date',
            value: controller.planStartDate.value,
            enabled: enabled,
            firstDate: DateTime(2013),
            lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
            onChanged: controller.onPlanStartPicked,
          ),
          const SizedBox(height: 12),
          AppDateField(
            label: 'Plan end date',
            value: controller.planEndDate.value,
            enabled: enabled,
            firstDate: DateTime(2013),
            lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
            initialDate: DateTime.now().add(const Duration(days: 365)),
            onChanged: (picked) => controller.planEndDate.value = picked,
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
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: InputDecoration(
              labelText: 'Core supports budget',
              prefixText: '\$ ',
              border: const OutlineInputBorder(),
              errorText: controller.budgetFieldError.value,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.budgetCbCtrl,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: InputDecoration(
              labelText: 'Capacity building budget',
              prefixText: '\$ ',
              border: const OutlineInputBorder(),
              errorText: controller.budgetFieldError.value,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.budgetCapitalCtrl,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: InputDecoration(
              labelText: 'Capital supports budget',
              prefixText: '\$ ',
              border: const OutlineInputBorder(),
              errorText: controller.budgetFieldError.value,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.budgetOtherLabelCtrl,
            enabled: enabled,
            decoration: const InputDecoration(
              labelText: 'Other budget label (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.budgetOtherCtrl,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: InputDecoration(
              labelText: 'Other budget amount',
              prefixText: '\$ ',
              border: const OutlineInputBorder(),
              errorText: controller.budgetFieldError.value,
            ),
          ),
        ],
      );
    });
  }
}
