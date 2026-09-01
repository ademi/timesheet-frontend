import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/support_plan_specialist_entry.dart';
import '../../models/support_plan_specialist_types.dart';
import '../../models/support_plan_specialist_entry.dart';
import 'support_plan_specialist_section.dart';

/// Dynamic list of support specialists with add/remove controls.
class SupportPlanSpecialistsPanel extends StatelessWidget {
  const SupportPlanSpecialistsPanel({
    super.key,
    required this.specialists,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
  });

  final RxList<SupportPlanSpecialistEntry> specialists;
  final bool enabled;
  final Future<void> Function(BuildContext context) onAdd;
  final void Function(String id) onRemove;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Support specialists (optional)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (final entry in specialists)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SupportPlanSpecialistSection(
                    entry: entry,
                    enabled: enabled,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed:
                          enabled ? () => onRemove(entry.id) : null,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Remove'),
                    ),
                  ),
                ],
              ),
            ),
          OutlinedButton.icon(
            onPressed: enabled ? () => onAdd(context) : null,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Add support specialist'),
          ),
        ],
      );
    });
  }

  static Future<void> showTypePicker(
    BuildContext context, {
    required void Function(String type) onSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'Add support specialist',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
              for (final type in SupportPlanSpecialistTypes.pickerTypes)
                ListTile(
                  title: Text(SupportPlanSpecialistTypes.labels[type]!),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onSelected(type);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
