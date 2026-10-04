import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';
import '../data/models/client_models.dart';
import '../utils/site_address_actions.dart';

class ClientDetailSitesSection extends StatelessWidget {
  const ClientDetailSitesSection({
    super.key,
    required this.sites,
    required this.stopsBySiteId,
    required this.canManage,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onAddStop,
    required this.onDeleteStop,
  });

  final List<ClientSiteOut> sites;
  final Map<String, List<ClientSiteStopOut>> stopsBySiteId;
  final bool canManage;
  final VoidCallback onAdd;
  final void Function(ClientSiteOut site) onEdit;
  final void Function(ClientSiteOut site) onDelete;
  final void Function(ClientSiteOut site) onAddStop;
  final void Function(ClientSiteOut site, ClientSiteStopOut stop) onDeleteStop;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Locations',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 8),
        const Text(
          'Latitude and longitude are required for geofence check-in. '
          'Add extra stops for community or transport sites.',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        if (canManage)
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cta,
                foregroundColor: AppColors.onPrimary,
              ),
            ),
          ),
        if (canManage) const SizedBox(height: 12),
        if (sites.isEmpty)
          const Text(
            'No locations yet.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        for (final site in sites)
          _SiteTile(
            site: site,
            stops: stopsBySiteId[site.id] ?? const [],
            canManage: canManage,
            onEdit: () => onEdit(site),
            onDelete: () => onDelete(site),
            onAddStop: () => onAddStop(site),
            onDeleteStop: (stop) => onDeleteStop(site, stop),
          ),
      ],
    );
  }
}

class _SiteTile extends StatelessWidget {
  const _SiteTile({
    required this.site,
    required this.stops,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
    required this.onAddStop,
    required this.onDeleteStop,
  });

  final ClientSiteOut site;
  final List<ClientSiteStopOut> stops;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddStop;
  final void Function(ClientSiteStopOut stop) onDeleteStop;

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
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
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
                        if (v == 'add_stop') onAddStop();
                      },
                      itemBuilder:
                          (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                              value: 'add_stop',
                              child: Text('Add stop'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                    ),
                ],
              ),
            ),
            if (stops.isNotEmpty || canManage)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  'Stops',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            if (stops.isEmpty && canManage)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'No extra stops — punches use the site point only.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            for (final stop in stops)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: const Icon(Icons.place_outlined, size: 20),
                title: Text(stop.label),
                subtitle: Text(
                  'lat ${stop.latitude}, lng ${stop.longitude} · '
                  '${stop.geofenceRadiusM}m',
                ),
                trailing:
                    canManage
                        ? IconButton(
                          tooltip: 'Remove stop',
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => onDeleteStop(stop),
                        )
                        : null,
              ),
            if (canManage)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onAddStop,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add stop'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
