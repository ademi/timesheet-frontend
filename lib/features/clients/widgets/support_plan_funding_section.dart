import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../controllers/support_plan_funding_consent_store.dart';

/// Care-plan Funding section (profile facts + NDIA PDF).
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
            onChanged: (v) => store.planManagementType.value = v,
          ),
          if (isPlanManaged) ...[
            const SizedBox(height: 12),
            TextField(
              controller: store.planManagerNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Plan manager name *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: store.planManagerPhoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Plan manager phone',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: store.planManagerEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Plan manager email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
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
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: store.planStartDate.value ?? DateTime.now(),
                firstDate: DateTime(2013),
                lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
              );
              if (picked != null) store.onPlanStartPicked(picked);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              store.planEndDate.value == null
                  ? 'Plan end date'
                  : 'End: ${_fmt(store.planEndDate.value!)}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: store.planEndDate.value ??
                    DateTime.now().add(const Duration(days: 365)),
                firstDate: DateTime(2013),
                lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
              );
              if (picked != null) store.planEndDate.value = picked;
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'Budgets (optional)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: store.budgetCoreCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Core support budget',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: store.budgetCbCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Capacity building budget',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: store.budgetCapitalCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Capital support budget',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: store.fundingNotToExceedCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Funding not to exceed',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Support coordinator (optional)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: store.scNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: store.scPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: store.scEmailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
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
            onChanged: (v) => store.preferredClaimingMethod.value = v,
          ),
          if (claiming == 'other') ...[
            const SizedBox(height: 12),
            TextField(
              controller: store.preferredClaimingOtherCtrl,
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
            onPressed: store.isBusy.value
                ? null
                : () => store.uploadNdisPlanPdf(clientId: clientId),
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
