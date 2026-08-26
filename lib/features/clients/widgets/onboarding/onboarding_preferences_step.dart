import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/client_onboarding_controller.dart';

class OnboardingPreferencesStep extends StatelessWidget {
  const OnboardingPreferencesStep({super.key, required this.controller});

  final ClientOnboardingController controller;

  static const swGenderOptions = ['Male', 'Female', 'No preference'];
  static const contactMethodOptions = ['Phone', 'Email', 'SMS', 'Any'];

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
          TextField(
            controller: controller.culturalPreferencesCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Cultural preferences',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: controller.homeVisitConsent.value,
            onChanged: (v) => controller.homeVisitConsent.value = v,
            title: const Text('Consent to home visit'),
          ),
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: controller.interpreterRequired.value,
            onChanged: (v) => controller.interpreterRequired.value = v,
            title: const Text('Interpreter required'),
          ),
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
        ],
      );
    });
  }
}
