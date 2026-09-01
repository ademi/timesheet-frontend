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
  static const editKey = ValueKey<String>('overview-edit');

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final canEdit = controller.canManage || controller.canManageProfile;
      final editing = controller.overviewEditing.value;
      final types = controller.clientTypes;
      final selectedTypeId = controller.overviewClientTypeId.value;
      final saving = controller.isSaving.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Identity',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              if (canEdit && !editing)
                TextButton.icon(
                  key: editKey,
                  onPressed: saving ? null : () => controller.overviewEditing.value = true,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!editing) ...[
            _ReadOnlyField(label: 'Full name', value: controller.overviewNameCtrl.text),
            _ReadOnlyField(label: 'Status', value: controller.overviewStatus.value),
            _ReadOnlyField(label: 'Email', value: controller.overviewEmailCtrl.text),
            _ReadOnlyField(label: 'Phone', value: controller.overviewPhoneCtrl.text),
            _ReadOnlyField(
              label: 'Date of birth',
              value: controller.overviewDob.value == null
                  ? ''
                  : _fmt(controller.overviewDob.value!),
            ),
            _ReadOnlyField(label: 'NDIS number', value: controller.overviewNdisCtrl.text),
            if (controller.showClientTypePicker && types.isNotEmpty) ...[
              Builder(
                builder: (context) {
                  final match = types.where((t) => t.id == selectedTypeId);
                  return _ReadOnlyField(
                    label: 'Type',
                    value: match.isEmpty ? '' : match.first.name,
                  );
                },
              ),
            ],
          ] else ...[
            TextField(
              key: fullNameKey,
              controller: controller.overviewNameCtrl,
              readOnly: saving,
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
                  saving
                      ? null
                      : (v) {
                        if (v != null) controller.overviewStatus.value = v;
                      },
            ),
            const SizedBox(height: 12),
            TextField(
              key: emailKey,
              controller: controller.overviewEmailCtrl,
              readOnly: saving,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                helperText:
                    'Email or phone required. Leave blank to keep the current value (clearing is not supported).',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: phoneKey,
              controller: controller.overviewPhoneCtrl,
              readOnly: saving,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(),
                helperText: 'Leave blank to keep the current value.',
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
              subtitle: const Text(
                'Tap to change. Clearing date of birth is not supported.',
                style: TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: saving ? null : () => controller.pickOverviewDob(context),
            ),
            const SizedBox(height: 12),
            TextField(
              key: ndisKey,
              controller: controller.overviewNdisCtrl,
              readOnly: saving,
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
                      saving ? null : controller.onOverviewClientTypeChanged,
                ),
            ],
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

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.trim().isEmpty ? '—' : value,
            style: const TextStyle(fontSize: 15),
          ),
        ],
      ),
    );
  }
}
