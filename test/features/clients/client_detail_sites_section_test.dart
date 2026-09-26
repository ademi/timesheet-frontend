import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/widgets/client_detail_sites_section.dart';

void main() {
  testWidgets('site tile shows address, stops, and action buttons', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 1, 1);
    final site = ClientSiteOut(
      id: 's1',
      tenantId: 't',
      clientId: 'c',
      name: 'Home',
      geofenceRadiusM: 100,
      isPrimary: true,
      createdAt: now,
      updatedAt: now,
      addressLine1: '12 Example St',
      city: 'Sydney',
      state: 'NSW',
      country: 'AU',
    );
    final stop = ClientSiteStopOut(
      id: 'stop-1',
      siteId: 's1',
      label: 'Day program',
      latitude: -33.9,
      longitude: 151.2,
      geofenceRadiusM: 80,
      sortOrder: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClientDetailSitesSection(
            sites: [site],
            stopsBySiteId: {
              's1': [stop],
            },
            canManage: false,
            onAdd: () {},
            onEdit: (_) {},
            onDelete: (_) {},
            onAddStop: (_) {},
            onDeleteStop: (_, __) {},
          ),
        ),
      ),
    );

    expect(find.textContaining('12 Example St'), findsOneWidget);
    expect(find.text('Day program'), findsOneWidget);
    expect(find.byTooltip('Open in Maps'), findsOneWidget);
    expect(find.byTooltip('Copy address'), findsOneWidget);
  });
}
