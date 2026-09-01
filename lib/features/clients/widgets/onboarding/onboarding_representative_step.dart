import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/themes/app_colors.dart';
import '../../../../shared/widgets/async_action.dart';
import '../../controllers/client_onboarding_controller.dart';
import '../../data/models/client_models.dart';
import '../contact_form_fields.dart';
import '../contact_form_host.dart';

class OnboardingRepresentativeStep extends StatelessWidget {
  const OnboardingRepresentativeStep({super.key, required this.controller});

  final ClientOnboardingController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final required = controller.requiresChildRepresentative;
      final saved = controller.representativeSaved.value;
      final editing = controller.representativeEditing.value;
      final skipped = controller.nomineeSkipped.value;
      final existing = controller.contactsCreated;
      final savedContact = controller.savedRepresentativeContact.value;

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
                ? 'A representative is required for participants under 18.'
                : 'Optionally add a nominee, or skip.',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              label: Text(controller.representativeRoleChipLabel),
              backgroundColor: AppColors.surface,
            ),
          ),
          const SizedBox(height: 12),
          if (saved && !editing && savedContact != null) ...[
            _RepresentativeSummary(
              contact: savedContact,
              onEdit: controller.beginEditRepresentative,
            ),
          ] else if (skipped && !required) ...[
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.skip_next, color: AppColors.textMuted),
              title: Text('Nominee skipped'),
            ),
          ] else ...[
            if (existing.isNotEmpty) ...[
              DropdownButtonFormField<String?>(
                value: controller.reuseEmergencyContactId.value,
                decoration: const InputDecoration(
                  labelText: 'Use existing contact as emergency',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Add a new contact'),
                  ),
                  for (final c in existing)
                    DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text(c.name ?? c.email ?? c.phone ?? 'Contact'),
                    ),
                ],
                onChanged: (id) async {
                  if (id == null) {
                    controller.reuseEmergencyContactId.value = null;
                    return;
                  }
                  await controller.useExistingAsEmergency(id);
                },
              ),
              const SizedBox(height: 12),
            ],
            if (!controller.showNewRepresentativeContactForm) ...[
              _ExistingEmergencySummary(
                contact: controller.selectedExistingEmergencyContact,
              ),
              const SizedBox(height: 12),
              AsyncOutlinedButton(
                onPressed: controller.saveExistingContactAsRepresentative,
                isLoading: controller.isSaving.value,
                child: Text(
                  required ? 'Save as representative' : 'Save as nominee',
                ),
              ),
            ] else ...[
              ContactFormFields(
                controller: controller,
                presets: ContactFormHost.kinshipPresets,
                showEmergencyCheckbox: false,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: controller.contactIsEmergency.value,
                onChanged: (v) =>
                    controller.contactIsEmergency.value = v ?? false,
                title: const Text('Also emergency contact'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (editing)
                    OutlinedButton(
                      onPressed: controller.cancelEditRepresentative,
                      child: const Text('Cancel'),
                    ),
                  if (editing) const SizedBox(width: 8),
                  Expanded(
                    child: AsyncOutlinedButton(
                      onPressed: () async {
                        await controller.saveContactDraft();
                      },
                      isLoading: controller.isSaving.value,
                      child: Text(
                        required ? 'Save representative' : 'Save nominee',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      );
    });
  }
}

class _ExistingEmergencySummary extends StatelessWidget {
  const _ExistingEmergencySummary({required this.contact});

  final ClientContactOut? contact;

  @override
  Widget build(BuildContext context) {
    if (contact == null) {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.check_circle, color: AppColors.primary),
        title: Text('Existing contact marked as emergency'),
      );
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.check_circle, color: AppColors.primary),
      title: Text(contact!.name ?? 'Emergency contact'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (contact!.phone?.trim().isNotEmpty == true) Text(contact!.phone!),
          if (contact!.email?.trim().isNotEmpty == true) Text(contact!.email!),
          const Text('Marked as emergency contact'),
        ],
      ),
    );
  }
}

class _RepresentativeSummary extends StatelessWidget {
  const _RepresentativeSummary({
    required this.contact,
    required this.onEdit,
  });

  final ClientContactOut contact;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final rel = contact.relationship?.trim();
    final relLabel = rel == null || rel.isEmpty
        ? null
        : ContactFormHost.relationshipPresets[rel] ?? rel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.check_circle, color: AppColors.primary),
          title: Text(contact.name ?? 'Representative'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (contact.phone?.trim().isNotEmpty == true)
                Text(contact.phone!),
              if (contact.email?.trim().isNotEmpty == true)
                Text(contact.email!),
              if (relLabel != null) Text('Relationship: $relLabel'),
              if (contact.isEmergency)
                const Text('Also emergency contact'),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit'),
          ),
        ),
      ],
    );
  }
}
