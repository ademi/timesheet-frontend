import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/clients_controller.dart';

/// Editable identity fields for the Overview tab (CR1).
class ClientDetailOverviewSection extends StatelessWidget {
  const ClientDetailOverviewSection({super.key, required this.controller});

  final ClientsController controller;

  static const fullNameKey = ValueKey<String>('overview-full-name');
  static const emailKey = ValueKey<String>('overview-email');
  static const phoneKey = ValueKey<String>('overview-phone');
  static const statusKey = ValueKey<String>('overview-status');
  static const dobKey = ValueKey<String>('overview-dob');
  static const ndisKey = ValueKey<String>('overview-ndis');
  static const typeKey = ValueKey<String>('overview-type');

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final canEdit = controller.canManage || controller.canManageProfile;
      final types = controller.clientTypes;
      final selectedTypeId = controller.overviewClientTypeId.value;
      final saving = controller.isSaving.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Identity',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 12),
          TextField(
            key: fullNameKey,
            controller: controller.overviewNameCtrl,
            readOnly: !canEdit || saving,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Full name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: statusKey,
            value: controller.overviewStatus.value,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'active', child: Text('Active')),
              DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
            ],
            onChanged:
                !canEdit || saving
                    ? null
                    : (v) {
                      if (v != null) controller.overviewStatus.value = v;
                    },
          ),
          const SizedBox(height: 12),
          TextField(
            key: emailKey,
            controller: controller.overviewEmailCtrl,
            readOnly: !canEdit || saving,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
              helperText: 'Email or phone is required',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: phoneKey,
            controller: controller.overviewPhoneCtrl,
            readOnly: !canEdit || saving,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            key: dobKey,
            contentPadding: EdgeInsets.zero,
            title: Text(
              controller.overviewDob.value == null
                  ? 'Date of birth'
                  : 'Date of birth: ${_fmt(controller.overviewDob.value!)}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap:
                !canEdit || saving
                    ? null
                    : () => controller.pickOverviewDob(context),
          ),
          const SizedBox(height: 12),
          TextField(
            key: ndisKey,
            controller: controller.overviewNdisCtrl,
            readOnly: !canEdit || saving,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'NDIS number',
              border: OutlineInputBorder(),
            ),
          ),
          if (controller.showClientTypePicker) ...[
            const SizedBox(height: 12),
            if (controller.isLoadingTypes.value)
              const LinearProgressIndicator(minHeight: 2)
            else if (types.isEmpty)
              const Text('No client types available.')
            else
              DropdownButtonFormField<String>(
                key: typeKey,
                value:
                    selectedTypeId != null &&
                            types.any((t) => t.id == selectedTypeId)
                        ? selectedTypeId
                        : null,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final t in types)
                    DropdownMenuItem(value: t.id, child: Text(t.name)),
                ],
                onChanged:
                    !canEdit || saving
                        ? null
                        : controller.onOverviewClientTypeChanged,
              ),
          ],
        ],
      );
    });
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
