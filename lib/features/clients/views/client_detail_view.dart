import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../controllers/clients_controller.dart';
import '../data/models/client_models.dart';

class ClientDetailView extends GetView<ClientsController> {
  const ClientDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final client = controller.selected.value;
      if (client == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Client')),
          body: const Center(child: Text('Client not found.')),
        );
      }
      final err = controller.errorMessage.value;
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(client.fullName),
          actions: [
            if (controller.canManage)
              IconButton(
                tooltip: 'Edit',
                onPressed: () => controller.openEdit(client),
                icon: const Icon(Icons.edit_outlined),
              ),
            if (controller.canManage)
              IconButton(
                tooltip: 'Delete',
                onPressed: () => controller.deleteClient(client),
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
        body: Column(
          children: [
            if (err != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    err,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${client.status}'
                  '${client.email != null ? ' · ${client.email}' : ''}'
                  '${client.phone != null ? ' · ${client.phone}' : ''}',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final entry in const [
                    (0, 'Sites'),
                    (1, 'Contacts'),
                    (2, 'Invites'),
                  ])
                    ChoiceChip(
                      label: Text(entry.$2),
                      selected: controller.tabIndex.value == entry.$1,
                      onSelected: (_) => controller.tabIndex.value = entry.$1,
                    ),
                ],
              ),
            ),
            Expanded(
              child: switch (controller.tabIndex.value) {
                1 => _ContactsTab(controller: controller),
                2 => _InvitesTab(controller: controller),
                _ => _SitesTab(controller: controller),
              },
            ),
          ],
        ),
      );
    });
  }
}

class _SitesTab extends StatelessWidget {
  const _SitesTab({required this.controller});
  final ClientsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (controller.canManage)
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: () => controller.beginSiteForm(),
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Add site'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                ),
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'Latitude and longitude are required for geofence check-in.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          if (controller.sites.isEmpty) const Text('No sites yet.'),
          for (final s in controller.sites) _SiteTile(site: s, c: controller),
        ],
      );
    });
  }
}

class _SiteTile extends StatelessWidget {
  const _SiteTile({required this.site, required this.c});
  final ClientSiteOut site;
  final ClientsController c;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(site.name),
        subtitle: Text(
          [
            if (site.addressLine1 != null) site.addressLine1!,
            if (site.hasCoordinates)
              'lat ${site.latitude}, lng ${site.longitude}'
            else
              'Missing coordinates',
            'geofence ${site.geofenceRadiusM}m'
            '${site.isPrimary ? ' · primary' : ''}',
          ].join('\n'),
        ),
        isThreeLine: true,
        trailing: c.canManage
            ? PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') c.beginSiteForm(site: site);
                  if (v == 'delete') c.deleteSite(site);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              )
            : null,
      ),
    );
  }
}

class _ContactsTab extends StatelessWidget {
  const _ContactsTab({required this.controller});
  final ClientsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (controller.canManage)
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: () => controller.beginContactForm(),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Add contact'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (controller.contacts.isEmpty) const Text('No contacts yet.'),
          for (final contact in controller.contacts)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(contact.name?.isNotEmpty == true
                    ? contact.name!
                    : (contact.email ?? contact.phone ?? 'Contact')),
                subtitle: Text(
                  [
                    if (contact.email != null) contact.email!,
                    if (contact.phone != null) contact.phone!,
                    if (contact.isPrimary) 'primary',
                    if (contact.notifyVisitComplete) 'notify on visit complete',
                  ].join(' · '),
                ),
                trailing: controller.canManage
                    ? PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'edit') {
                            controller.beginContactForm(contact: contact);
                          }
                          if (v == 'delete') {
                            controller.deleteContact(contact);
                          }
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
    });
  }
}

class _InvitesTab extends StatelessWidget {
  const _InvitesTab({required this.controller});
  final ClientsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final invite = controller.lastInvite.value;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Create a one-time client invite token. There is no staff list of '
            'past invites yet (see BH-007).',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          if (controller.canManage)
            ElevatedButton.icon(
              onPressed:
                  controller.isSaving.value ? null : controller.createInvite,
              icon: const Icon(Icons.link),
              label: const Text('Create invite token'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
            ),
          if (invite != null) ...[
            const SizedBox(height: 16),
            Text(
              'Expires: ${invite.expiresAt.toLocal()}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SelectableText(controller.invitePath(invite.token)),
            const SizedBox(height: 4),
            Text(
              'Also accepted: ${controller.legacyInvitePath(invite.token)} '
              '(backend email path — BH-005)',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => controller.copyInviteLink(invite.token),
              icon: const Icon(Icons.copy),
              label: const Text('Copy Flutter path'),
            ),
          ],
        ],
      );
    });
  }
}
