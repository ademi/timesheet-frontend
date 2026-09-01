import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../controllers/support_plan_funding_consent_store.dart';
import 'onboarding/support_plan_specialists_panel.dart';

/// Care-plan Support Plan section (profile facts + NDIA PDF).
class SupportPlanFundingSection extends StatelessWidget {
  const SupportPlanFundingSection({
    super.key,
    required this.store,
    required this.clientId,
  });

  final SupportPlanFundingConsentStore store;
  final String clientId;

  static const planTypes = <String, String>{
    'ndia': 'NDIA managed',
    'plan_managed': 'Plan managed',
    'self_managed': 'Self managed',
  };

  static const claimingMethods = <String, String>{
    'provider_claim_ndia': 'Provider claims from NDIA',
    'invoice_plan_manager': 'Invoice plan manager',
    'participant_pays': 'Participant pays',
    'other': 'Other',
  };

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final planType = store.planManagementType.value;
      final isPlanManaged = planType == 'plan_managed';
      final claiming = store.preferredClaimingMethod.value;
      final enabled = !store.isBusy.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Support Plan',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: store.ndisCtrl,
            enabled: enabled,
            decoration: InputDecoration(
              labelText: 'NDIS number',
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              errorText: store.ndisFieldError.value,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: store.supportPlanOtherCtrl,
            enabled: enabled,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Other',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            value: planType,
            decoration: const InputDecoration(
              labelText: 'Plan management type',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Select'),
              ),
              for (final e in planTypes.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: enabled ? (v) => store.planManagementType.value = v : null,
          ),
          if (isPlanManaged) ...[
            const SizedBox(height: 16),
            const Text(
              'Plan manager details',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: store.planManagerNameCtrl,
              enabled: enabled,
              decoration: const InputDecoration(
                labelText: 'Plan manager name *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: store.planManagerCompanyCtrl,
              enabled: enabled,
              decoration: const InputDecoration(
                labelText: 'Company name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: store.planManagerAbnAcnCtrl,
              enabled: enabled,
              decoration: const InputDecoration(
                labelText: 'ACN/ABN',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: store.planManagerOrgIdCtrl,
              enabled: enabled,
              decoration: const InputDecoration(
                labelText: 'Organisation ID',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: store.planManagerPhoneCtrl,
              enabled: enabled,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: store.planManagerEmailCtrl,
              enabled: enabled,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: store.planManagerAddressCtrl,
              enabled: enabled,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
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
              store.planStartDate.value == null
                  ? 'Plan start date'
                  : 'Start: ${_fmt(store.planStartDate.value!)}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: enabled
                ? () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          store.planStartDate.value ?? DateTime.now(),
                      firstDate: DateTime(2013),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (picked != null) store.onPlanStartPicked(picked);
                  }
                : null,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              store.planEndDate.value == null
                  ? 'Plan end date'
                  : 'End: ${_fmt(store.planEndDate.value!)}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: enabled
                ? () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: store.planEndDate.value ??
                          DateTime.now().add(const Duration(days: 365)),
                      firstDate: DateTime(2013),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (picked != null) store.planEndDate.value = picked;
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
            controller: store.budgetCoreCtrl,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: const InputDecoration(
              labelText: 'Core supports budget',
              prefixText: '\$ ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: store.budgetCbCtrl,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: const InputDecoration(
              labelText: 'Capacity building budget',
              prefixText: '\$ ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: store.budgetCapitalCtrl,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: const InputDecoration(
              labelText: 'Capital supports budget',
              prefixText: '\$ ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: store.budgetOtherLabelCtrl,
            enabled: enabled,
            decoration: const InputDecoration(
              labelText: 'Other budget label (optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: store.budgetOtherCtrl,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: const InputDecoration(
              labelText: 'Other budget amount',
              prefixText: '\$ ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SupportPlanSpecialistsPanel(
            specialists: store.supportSpecialists,
            enabled: enabled,
            onAdd: (context) => SupportPlanSpecialistsPanel.showTypePicker(
              context,
              onSelected: store.addSupportSpecialist,
            ),
            onRemove: store.removeSupportSpecialist,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            value: claiming,
            decoration: const InputDecoration(
              labelText: 'Preferred claiming method',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Select'),
              ),
              for (final e in claimingMethods.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged:
                enabled ? (v) => store.preferredClaimingMethod.value = v : null,
          ),
          if (claiming == 'other') ...[
            const SizedBox(height: 12),
            TextField(
              controller: store.preferredClaimingOtherCtrl,
              enabled: enabled,
              decoration: const InputDecoration(
                labelText: 'Other claiming detail *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'NDIA plan PDF',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (store.ndisPdfOnFile.value)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'PDF on file',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
          OutlinedButton.icon(
            onPressed: enabled
                ? () => store.uploadNdisPlanPdf(clientId: clientId)
                : null,
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(
              store.ndisPdfOnFile.value
                  ? 'Replace NDIA plan PDF'
                  : 'Upload NDIA plan PDF',
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
