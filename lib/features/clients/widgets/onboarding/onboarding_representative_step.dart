import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/themes/app_colors.dart';
import '../../../../shared/widgets/async_action.dart';
import '../../controllers/client_onboarding_controller.dart';
import '../../utils/onboarding_keys.dart';
import '../contact_form_fields.dart';

class OnboardingRepresentativeStep extends StatelessWidget {
  const OnboardingRepresentativeStep({super.key, required this.controller});

  final ClientOnboardingController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final required = controller.requiresChildRepresentative;
      final saved = controller.representativeSaved.value;
      final skipped = controller.nomineeSkipped.value;
      final rel = required
          ? OnboardingKeys.relChildRepresentative
          : OnboardingKeys.relNominee;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            controller.representativeStepTitle,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            required
                ? 'A child representative is required for participants under 18.'
                : 'Optionally add a nominee, or skip.',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (saved) ...[
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.check_circle, color: AppColors.primary),
              title: Text('Representative saved'),
            ),
          ] else if (skipped && !required) ...[
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.skip_next, color: AppColors.textMuted),
              title: Text('Nominee skipped'),
            ),
          ] else ...[
            ContactFormFields(
              controller: controller,
              lockRelationship: rel,
            ),
            const SizedBox(height: 12),
            AsyncOutlinedButton(
              onPressed: () async {
                controller.contactRelationshipPreset.value = rel;
                await controller.saveContactDraft();
              },
              isLoading: controller.isSaving.value,
              child: Text(required ? 'Save child representative' : 'Save nominee'),
            ),
          ],
        ],
      );
    });
  }
}
