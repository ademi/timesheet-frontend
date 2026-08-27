import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';
import '../controllers/clients_controller.dart';
import '../data/models/client_models.dart';

class ClientDetailContactsSection extends StatelessWidget {
  const ClientDetailContactsSection({
    super.key,
    required this.contacts,
    required this.canManage,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ClientContactOut> contacts;
  final bool canManage;
  final VoidCallback onAdd;
  final void Function(ClientContactOut contact) onEdit;
  final void Function(ClientContactOut contact) onDelete;

  static String? _relationshipLabel(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final key = raw.trim();
    return ClientsController.relationshipPresets[key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Contacts',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 12),
        if (canManage)
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add contact'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
            ),
          ),
        if (canManage) const SizedBox(height: 12),
        if (contacts.isEmpty)
          const Text(
            'No contacts yet.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        for (final contact in contacts)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: AppColors.cardBackground,
            child: ListTile(
              title: Text(
                contact.name?.isNotEmpty == true
                    ? contact.name!
                    : (contact.email ?? contact.phone ?? 'Contact'),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      if (_relationshipLabel(contact.relationship) != null)
                        _relationshipLabel(contact.relationship)!,
                      if (contact.email != null) contact.email!,
                      if (contact.phone != null) contact.phone!,
                      if (contact.isPrimary) 'primary',
                    ].join(' · '),
                  ),
                  if (contact.isEmergency)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Chip(
                        label: const Text('Emergency'),
                        backgroundColor: AppColors.openSlotBackground,
                        side: const BorderSide(color: AppColors.openSlot),
                        labelStyle: const TextStyle(
                          fontSize: 12,
                          color: AppColors.openSlot,
                        ),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  if (contact.notifyVisitComplete)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'notify on visit complete',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
              trailing: canManage
                  ? PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') onEdit(contact);
                        if (v == 'delete') onDelete(contact);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    )
                  : null,
            ),
          ),
      ],
    );
  }
}
