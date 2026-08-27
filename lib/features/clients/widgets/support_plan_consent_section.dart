import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../controllers/support_plan_funding_consent_store.dart';

/// Care-plan Consent & agreements section (legal status + share flags).
class SupportPlanConsentSection extends StatelessWidget {
  const SupportPlanConsentSection({
    super.key,
    required this.store,
    required this.clientId,
  });

  final SupportPlanFundingConsentStore store;
  final String clientId;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final busy = store.isBusy.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Consent & agreements',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Linked to onboarding Legal pack / Profile & docs',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          _LegalRow(
            label: 'Consent agreement',
            complete: store.consentAgreementComplete.value,
          ),
          if (!store.consentAgreementComplete.value) ...[
            const SizedBox(height: 8),
            TextField(
              controller: store.consentSignerNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Participant or representative name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => store.markConsentComplete(clientId: clientId),
              child: const Text('Upload Consent PDF'),
            ),
          ],
          const SizedBox(height: 12),
          _LegalRow(
            label: 'Service agreement',
            complete: store.serviceAgreementComplete.value,
          ),
          if (!store.serviceAgreementComplete.value) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => store.markServiceAgreementComplete(clientId: clientId),
              child: const Text('Upload Service Agreement PDF'),
            ),
          ],
          const SizedBox(height: 12),
          _LegalRow(
            label: 'Acknowledgement (optional)',
            complete: store.acknowledgementComplete.value,
          ),
          if (!store.acknowledgementComplete.value) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => store.markAcknowledgementComplete(clientId: clientId),
              child: const Text('Upload Acknowledgement PDF'),
            ),
          ],
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Information share'),
            subtitle: const Text(
              'Information may be shared with relevant providers',
            ),
            value: store.infoShareConsent.value,
            onChanged: (v) => store.infoShareConsent.value = v,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Specific supports'),
            subtitle: const Text(
              'Consented to specific supports in this plan',
            ),
            value: store.specificSupportsConsent.value,
            onChanged: (v) => store.specificSupportsConsent.value = v,
          ),
        ],
      );
    });
  }
}

class _LegalRow extends StatelessWidget {
  const _LegalRow({required this.label, required this.complete});

  final String label;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          complete ? Icons.check_circle : Icons.radio_button_unchecked,
          color: complete ? AppColors.success : AppColors.textMuted,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          complete ? 'Complete' : 'Missing',
          style: TextStyle(
            fontSize: 12,
            color: complete ? AppColors.success : AppColors.openSlot,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
