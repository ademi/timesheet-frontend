import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../shared/widgets/other_text_field.dart';
import '../../../../shared/widgets/profile_photo_editor.dart';
import '../../controllers/client_onboarding_controller.dart';
import 'onboarding_identity_card_field.dart';

class OnboardingIdentityStep extends StatelessWidget {
  const OnboardingIdentityStep({super.key, required this.controller});

  final ClientOnboardingController controller;

  static const otherPresetKey = 'Other';

  static const sexOptions = [
    'Male',
    'Female',
    'Non-binary',
    'Prefer not to say'
  ];
  static const atsiOptions = [
    'Aboriginal',
    'Torres Strait Islander',
    'Aboriginal & Torres Strait Islander',
    'No',
  ];
  static const referralOptions = [
    'Friend/Family',
    'Self Referred',
    otherPresetKey,
  ];

  /// Maps stored referral to UI preset + free-text companion (CR5).
  static ({String? preset, String otherText}) hydrateReferral(String? stored) {
    final v = stored?.trim();
    if (v == null || v.isEmpty) {
      return (preset: null, otherText: '');
    }
    if (v.toLowerCase() == 'other') {
      return (preset: otherPresetKey, otherText: '');
    }
    if (referralOptions.contains(v) && v != otherPresetKey) {
      return (preset: v, otherText: '');
    }
    if (v == otherPresetKey) {
      return (preset: otherPresetKey, otherText: '');
    }
    return (preset: otherPresetKey, otherText: v);
  }

  /// Maps stored sex/gender to UI preset + free-text companion (CR5).
  static ({String? preset, String otherText}) hydrateSexGender(String? stored) {
    final v = stored?.trim();
    if (v == null || v.isEmpty) {
      return (preset: null, otherText: '');
    }
    if (v.toLowerCase() == 'other') {
      return (preset: otherPresetKey, otherText: '');
    }
    if (sexOptions.contains(v) && v != otherPresetKey) {
      return (preset: v, otherText: '');
    }
    if (v == otherPresetKey) {
      return (preset: otherPresetKey, otherText: '');
    }
    return (preset: otherPresetKey, otherText: v);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final enabled = !controller.isSaving.value;

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
            enabled: enabled,
            onChanged: controller.onPhotoPicked,
            onRemove: controller.clearPhoto,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller.fullName,
            decoration: const InputDecoration(
              labelText: 'Participant full name *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: controller.sexGender.value,
            decoration: const InputDecoration(
              labelText: 'Participant gender',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Select'),
              ),
              for (final o in sexOptions)
                DropdownMenuItem(value: o, child: Text(o)),
              const DropdownMenuItem(
                value: otherPresetKey,
                child: Text(otherPresetKey),
              ),
            ],
            onChanged: enabled
                ? (v) {
                    controller.sexGender.value = v;
                    if (v != otherPresetKey) {
                      controller.sexGenderOtherCtrl.clear();
                    }
                  }
                : null,
          ),
          OtherTextField(
            isOther: controller.sexGender.value == otherPresetKey,
            controller: controller.sexGenderOtherCtrl,
            label: 'Participant gender (other)',
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              controller.dob.value == null
                  ? 'Participant date of birth *'
                  : 'DOB: ${_fmt(controller.dob.value!)}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: enabled
                ? () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          controller.dob.value ?? DateTime(now.year - 30),
                      firstDate: DateTime(1900),
                      lastDate: now,
                    );
                    if (picked != null) controller.dob.value = picked;
                  }
                : null,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Participant phone number *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Participant email *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          OnboardingIdentityCardField(
            label: 'Participant Medicare (optional)',
            numberController: controller.medicareCtrl,
            numberLabel: 'Medicare number (optional)',
            attachment: controller.medicareCardAttachment,
            enabled: enabled,
            onPick: () => controller.pickIdentityCard(
              controller.medicareCardAttachment,
            ),
            onClearPending: () => controller.clearIdentityCardPending(
              controller.medicareCardAttachment,
            ),
          ),
          OnboardingIdentityCardField(
            label: 'Participant Companion card (optional)',
            numberController: controller.companionCardNumberCtrl,
            numberLabel: 'Companion card number (optional)',
            attachment: controller.companionCardAttachment,
            enabled: enabled,
            onPick: () => controller.pickIdentityCard(
              controller.companionCardAttachment,
            ),
            onClearPending: () => controller.clearIdentityCardPending(
              controller.companionCardAttachment,
            ),
          ),
          OnboardingIdentityCardField(
            label: 'Participant Disability card (optional)',
            attachment: controller.disabilityCardAttachment,
            enabled: enabled,
            onPick: () => controller.pickIdentityCard(
              controller.disabilityCardAttachment,
            ),
            onClearPending: () => controller.clearIdentityCardPending(
              controller.disabilityCardAttachment,
            ),
          ),
          OnboardingIdentityCardField(
            label: 'Participant Pension card (optional)',
            numberController: controller.pensionCardNumberCtrl,
            numberLabel: 'Pension card number (optional)',
            attachment: controller.pensionCardAttachment,
            enabled: enabled,
            onPick: () => controller.pickIdentityCard(
              controller.pensionCardAttachment,
            ),
            onClearPending: () => controller.clearIdentityCardPending(
              controller.pensionCardAttachment,
            ),
          ),
          OnboardingIdentityCardField(
            label: 'Participant photo ID / passport (optional)',
            numberController: controller.photoIdNumberCtrl,
            numberLabel: 'ID number (optional)',
            attachment: controller.photoIdAttachment,
            enabled: enabled,
            onPick: () => controller.pickIdentityCard(
              controller.photoIdAttachment,
            ),
            onClearPending: () => controller.clearIdentityCardPending(
              controller.photoIdAttachment,
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
            onChanged: enabled
                ? (v) {
                    controller.referralSource.value = v;
                    if (v != otherPresetKey) {
                      controller.referralOtherCtrl.clear();
                    }
                  }
                : null,
          ),
          OtherTextField(
            isOther: controller.referralSource.value == otherPresetKey,
            controller: controller.referralOtherCtrl,
            label: 'Referral source (other)',
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
            onChanged: enabled ? (v) => controller.atsiStatus.value = v : null,
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
