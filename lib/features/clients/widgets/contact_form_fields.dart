import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'contact_form_host.dart';

/// Shared contact fields: name, email, phone, relationship, primary.
///
/// Does **not** include notify-on-visit-complete (D15).
class ContactFormFields extends StatelessWidget {
  const ContactFormFields({
    super.key,
    required this.controller,
    this.lockRelationship,
    this.hideRelationship = false,
  });

  final ContactFormHost controller;

  /// When set, relationship dropdown is locked to this preset key.
  final String? lockRelationship;

  /// Hide relationship UI entirely (caller sets preset).
  final bool hideRelationship;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final preset = lockRelationship ?? controller.contactRelationshipPreset.value;
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
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Select relationship'),
                ),
                for (final entry in ContactFormHost.relationshipPresets.entries)
                  DropdownMenuItem<String?>(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                const DropdownMenuItem<String?>(
                  value: ContactFormHost.relationshipOtherKey,
                  child: Text('Other'),
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
        ],
      );
    });
  }
}
