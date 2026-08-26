import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/clients_controller.dart';

/// Shared contact fields: name, email, phone, relationship, primary.
///
/// Does **not** include notify-on-visit-complete (D15).
class ContactFormFields extends StatelessWidget {
  const ContactFormFields({
    super.key,
    required this.controller,
  });

  final ClientsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final preset = controller.contactRelationshipPreset.value;
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
              for (final entry
                  in ClientsController.relationshipPresets.entries)
                DropdownMenuItem<String?>(
                  value: entry.key,
                  child: Text(entry.value),
                ),
              const DropdownMenuItem<String?>(
                value: ClientsController.relationshipOtherKey,
                child: Text('Other'),
              ),
            ],
            onChanged: (v) => controller.contactRelationshipPreset.value = v,
          ),
          if (preset == ClientsController.relationshipOtherKey) ...[
            const SizedBox(height: 12),
            TextField(
              controller: controller.contactRelationshipOtherCtrl,
              decoration: const InputDecoration(
                labelText: 'Relationship (other)',
                border: OutlineInputBorder(),
              ),
            ),
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
