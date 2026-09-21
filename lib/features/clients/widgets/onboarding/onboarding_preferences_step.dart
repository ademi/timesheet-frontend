import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../shared/widgets/app_switch_field.dart';
import '../../controllers/client_onboarding_controller.dart';

class OnboardingPreferencesStep extends StatelessWidget {
  const OnboardingPreferencesStep({super.key, required this.controller});

  final ClientOnboardingController controller;

  static const swGenderOptions = ['Male', 'Female', 'No preference'];
  static const contactMethodOptions = ['Phone', 'Email', 'SMS', 'Any'];

  static const culturalPreferencesHint =
      'e.g. Prefers female workers for personal care; '
      'Halal meals only; observes Ramadan — no visits at Maghrib; '
      'Aboriginal — ask before entering, no photos without consent; '
      'Arabic at home, simple English for booking';

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Preferences',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.preferredLanguageCtrl,
            decoration: const InputDecoration(
              labelText: 'Preferred language',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          AppSwitchField(
            label: 'Interpreter required',
            value: controller.interpreterRequired.value,
            onChanged: (v) {
              controller.interpreterRequired.value = v;
              if (!v) controller.interpreterLanguageCtrl.clear();
            },
          ),
          if (controller.interpreterRequired.value) ...[
            const SizedBox(height: 12),
            TextField(
              controller: controller.interpreterLanguageCtrl,
              decoration: const InputDecoration(
                labelText: 'Interpreter language',
                hintText: 'e.g. Mandarin, Arabic, Auslan',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          AppSwitchField(
            label: 'Consent to home visit',
            value: controller.homeVisitConsent.value,
            onChanged: (v) => controller.homeVisitConsent.value = v,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: controller.preferredContactMethod.value,
            decoration: const InputDecoration(
              labelText: 'Preferred contact method',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Select'),
              ),
              for (final o in contactMethodOptions)
                DropdownMenuItem(value: o, child: Text(o)),
            ],
            onChanged: (v) => controller.preferredContactMethod.value = v,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: controller.swGenderPreference.value,
            decoration: const InputDecoration(
              labelText: 'Support worker gender preference',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Select'),
              ),
              for (final o in swGenderOptions)
                DropdownMenuItem(value: o, child: Text(o)),
            ],
            onChanged: (v) => controller.swGenderPreference.value = v,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.culturalPreferencesCtrl,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Cultural preferences',
              hintText: culturalPreferencesHint,
              hintMaxLines: 4,
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ],
      );
    });
  }
}
