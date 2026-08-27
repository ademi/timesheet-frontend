import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/themes/app_colors.dart';
import '../../../../shared/widgets/async_action.dart';
import '../../controllers/client_onboarding_controller.dart';
import '../../utils/onboarding_keys.dart';
import '../contact_form_fields.dart';

class OnboardingContactsStep extends StatelessWidget {
  const OnboardingContactsStep({super.key, required this.controller});

  final ClientOnboardingController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final emergencyDone = controller.emergencySaved.value;
      final carerDone = controller.carerSaved.value;
      final mode = controller.contactDraftMode.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Contacts',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            emergencyDone
                ? 'Emergency contact saved. Optionally add a carer.'
                : 'Add an emergency contact (required).',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (controller.contactsCreated.isNotEmpty) ...[
            for (final c in controller.contactsCreated)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline),
                title: Text(c.name ?? c.email ?? c.phone ?? 'Contact'),
                subtitle: Text(c.relationship ?? ''),
              ),
            const Divider(),
          ],
          if (!emergencyDone || mode == 'emergency') ...[
            if (!emergencyDone)
              ContactFormFields(
                controller: controller,
                lockRelationship: OnboardingKeys.relEmergency,
              ),
            if (!emergencyDone) ...[
              const SizedBox(height: 12),
              AsyncOutlinedButton(
                onPressed: () async {
                  controller.contactRelationshipPreset.value =
                      OnboardingKeys.relEmergency;
                  await controller.saveContactDraft();
                },
                isLoading: controller.isSaving.value,
                child: const Text('Save emergency contact'),
              ),
            ],
          ] else ...[
            if (!carerDone && mode == 'carer') ...[
              ContactFormFields(
                controller: controller,
                lockRelationship: OnboardingKeys.relCarer,
              ),
              const SizedBox(height: 12),
              AsyncOutlinedButton(
                onPressed: () async {
                  controller.contactRelationshipPreset.value =
                      OnboardingKeys.relCarer;
                  await controller.saveContactDraft();
                },
                isLoading: controller.isSaving.value,
                child: const Text('Save carer'),
              ),
            ] else if (mode == 'more') ...[
              ContactFormFields(controller: controller),
              const SizedBox(height: 12),
              AsyncOutlinedButton(
                onPressed: controller.saveContactDraft,
                isLoading: controller.isSaving.value,
                child: const Text('Save contact'),
              ),
            ] else ...[
              OutlinedButton(
                onPressed: controller.beginCarerDraft,
                child: Text(
                  carerDone ? 'Add another contact' : 'Add optional carer',
                ),
              ),
              if (carerDone)
                TextButton(
                  onPressed: controller.beginMoreContactDraft,
                  child: const Text('Add another contact'),
                ),
            ],
          ],
          if (emergencyDone)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Press Next when contacts are ready.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
        ],
      );
    });
  }
}
