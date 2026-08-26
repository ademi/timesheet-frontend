import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../shared/widgets/profile_photo_editor.dart';
import '../../controllers/client_onboarding_controller.dart';

class OnboardingIdentityStep extends StatelessWidget {
  const OnboardingIdentityStep({super.key, required this.controller});

  final ClientOnboardingController controller;

  static const sexOptions = [
    'Male',
    'Female',
    'Non-binary',
    'Undisclosed',
    'Prefer not to say',
  ];
  static const atsiOptions = [
    'Aboriginal',
    'Torres Strait Islander',
    'Aboriginal & Torres Strait Islander',
    'No',
  ];
  static const referralOptions = [
    'NDIS',
    'LAC',
    'Friend/Family',
    'Self Referred',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Participant identity',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 12),
          ProfilePhotoEditor(
            localBytes: controller.localPhotoBytes.value,
            enabled: !controller.isSaving.value,
            onChanged: controller.onPhotoPicked,
            onRemove: controller.clearPhoto,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller.fullName,
            decoration: const InputDecoration(
              labelText: 'Full name *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              controller.dob.value == null
                  ? 'Date of birth *'
                  : 'DOB: ${_fmt(controller.dob.value!)}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: controller.dob.value ?? DateTime(now.year - 30),
                firstDate: DateTime(1900),
                lastDate: now,
              );
              if (picked != null) controller.dob.value = picked;
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.ndisCtrl,
            decoration: InputDecoration(
              labelText: 'NDIS number *',
              border: const OutlineInputBorder(),
              errorText: controller.ndisFieldError.value,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.medicareCtrl,
            decoration: const InputDecoration(
              labelText: 'Medicare card (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: controller.referralSource.value,
            decoration: const InputDecoration(
              labelText: 'Referred by',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Select'),
              ),
              for (final o in referralOptions)
                DropdownMenuItem(value: o, child: Text(o)),
            ],
            onChanged: (v) => controller.referralSource.value = v,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: controller.sexGender.value,
            decoration: const InputDecoration(
              labelText: 'Sex / gender',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Select'),
              ),
              for (final o in sexOptions)
                DropdownMenuItem(value: o, child: Text(o)),
            ],
            onChanged: (v) => controller.sexGender.value = v,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: controller.atsiStatus.value,
            decoration: const InputDecoration(
              labelText: 'Aboriginal and/or Torres Strait Islander',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Select'),
              ),
              for (final o in atsiOptions)
                DropdownMenuItem(value: o, child: Text(o)),
            ],
            onChanged: (v) => controller.atsiStatus.value = v,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.allergiesCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Allergies (optional)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
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
