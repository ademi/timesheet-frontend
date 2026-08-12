import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';
import '../data/models/client_models.dart';
import '../utils/site_address_actions.dart';

class ClientDetailSitesSection extends StatelessWidget {
  const ClientDetailSitesSection({
    super.key,
    required this.sites,
    required this.canManage,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ClientSiteOut> sites;
  final bool canManage;
  final VoidCallback onAdd;
  final void Function(ClientSiteOut site) onEdit;
  final void Function(ClientSiteOut site) onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sites',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 8),
        const Text(
          'Latitude and longitude are required for geofence check-in.',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        if (canManage)
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add site'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
            ),
          ),
        if (canManage) const SizedBox(height: 12),
        if (sites.isEmpty)
          const Text(
            'No sites yet.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        for (final site in sites)
          _SiteTile(
            site: site,
            canManage: canManage,
            onEdit: () => onEdit(site),
            onDelete: () => onDelete(site),
          ),
      ],
    );
  }
}

class _SiteTile extends StatelessWidget {
  const _SiteTile({
    required this.site,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  final ClientSiteOut site;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title = site.isPrimary ? '${site.name} · primary' : site.name;
    final subtitle = [
      site.displayAddress,
      if (site.hasCoordinates)
        'lat ${site.latitude}, lng ${site.longitude}'
      else
        'Missing coordinates',
      'geofence ${site.geofenceRadiusM}m',
    ].join('\n');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.cardBackground,
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Open in Maps',
              icon: const Icon(Icons.map_outlined),
              onPressed: () => openSiteInMaps(site),
            ),
            IconButton(
              tooltip: 'Copy address',
              icon: const Icon(Icons.copy_outlined),
              onPressed: () => copySiteAddress(context, site),
            ),
            if (canManage)
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
