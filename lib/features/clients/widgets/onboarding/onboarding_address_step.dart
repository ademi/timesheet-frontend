import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/client_onboarding_controller.dart';
import '../site_form_fields.dart';

class OnboardingAddressStep extends StatelessWidget {
  const OnboardingAddressStep({super.key, required this.controller});

  final ClientOnboardingController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Primary address',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Confirm the looked-up address. Postal code is required.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          SiteFormFields(
            controller: controller,
            primaryMode: true,
            nameAtEnd: true,
          ),
          if (controller.primarySiteSaved.value) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: controller.openAddLocation,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add location'),
            ),
          ],
        ],
      );
    });
  }
}
