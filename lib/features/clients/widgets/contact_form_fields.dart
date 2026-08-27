import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'contact_form_host.dart';

/// Shared contact fields: name, email, phone, relationship, primary, emergency.
///
/// Does **not** include notify-on-visit-complete (D15).
class ContactFormFields extends StatelessWidget {
  const ContactFormFields({
    super.key,
    required this.controller,
    this.lockRelationship,
    this.hideRelationship = false,
    this.showEmergencyCheckbox = true,
    this.presets,
  });

  final ContactFormHost controller;

  /// When set, relationship dropdown is locked to this preset key.
  final String? lockRelationship;

  /// Hide relationship UI entirely (caller sets preset).
  final bool hideRelationship;

  /// Contacts step / standalone form. Representative uses its own checkbox.
  final bool showEmergencyCheckbox;

  /// Defaults to [ContactFormHost.kinshipPresets].
  final Map<String, String>? presets;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final preset = lockRelationship ?? controller.contactRelationshipPreset.value;
      final map = presets ?? ContactFormHost.kinshipPresets;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller.contactNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.contactEmailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.contactPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone',
              border: OutlineInputBorder(),
            ),
          ),
          if (!hideRelationship) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: preset,
              decoration: const InputDecoration(
                labelText: 'Relationship',
                border: OutlineInputBorder(),
              ),
              items: [
                if (lockRelationship == null)
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Select relationship'),
                  ),
                for (final entry in map.entries)
                  DropdownMenuItem<String?>(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                if (lockRelationship != null && !map.containsKey(lockRelationship))
                  DropdownMenuItem<String?>(
                    value: lockRelationship,
                    child: Text(lockRelationship!),
                  ),
                if (preset == ContactFormHost.relationshipOtherKey)
                  const DropdownMenuItem<String?>(
                    value: ContactFormHost.relationshipOtherKey,
                    child: Text('Other (custom)'),
                  ),
              ],
              onChanged: lockRelationship != null
                  ? null
                  : (v) => controller.contactRelationshipPreset.value = v,
            ),
            if (preset == ContactFormHost.relationshipOtherKey) ...[
              const SizedBox(height: 12),
              TextField(
                controller: controller.contactRelationshipOtherCtrl,
                decoration: const InputDecoration(
                  labelText: 'Relationship (other)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: controller.contactIsPrimary.value,
            onChanged: (v) => controller.contactIsPrimary.value = v,
            title: const Text('Primary contact'),
          ),
          if (showEmergencyCheckbox)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: controller.contactIsEmergency.value,
              onChanged: (v) => controller.contactIsEmergency.value = v ?? false,
              title: const Text('Emergency contact'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
        ],
      );
    });
  }
}
