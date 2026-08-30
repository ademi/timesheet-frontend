import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/support_plan_professional_fields.dart';

/// Collapsible optional professional block for Support Plan onboarding.
class SupportPlanProfessionalSection extends StatelessWidget {
  const SupportPlanProfessionalSection({
    super.key,
    required this.title,
    required this.fields,
    required this.expanded,
    required this.enabled,
    required this.nameLabel,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String nameLabel;
  final SupportPlanProfessionalFields fields;
  final RxBool expanded;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return ExpansionTile(
        initiallyExpanded: expanded.value,
        onExpansionChanged: (v) => expanded.value = v,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!, style: const TextStyle(fontSize: 12)),
        children: [
          TextField(
            controller: fields.nameCtrl,
            enabled: enabled,
            decoration: InputDecoration(
              labelText: nameLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: fields.companyCtrl,
            enabled: enabled,
            decoration: const InputDecoration(
              labelText: 'Company name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: fields.abnAcnCtrl,
            enabled: enabled,
            decoration: const InputDecoration(
              labelText: 'ACN/ABN',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: fields.orgIdCtrl,
            enabled: enabled,
            decoration: const InputDecoration(
              labelText: 'Organisation ID',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: fields.phoneCtrl,
            enabled: enabled,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: fields.emailCtrl,
            enabled: enabled,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: fields.addressCtrl,
            enabled: enabled,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Address',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
        ],
      );
    });
  }
}
