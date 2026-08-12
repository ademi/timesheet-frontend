import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1);

  test('displayAddress joins non-empty address parts', () {
    final site = ClientSiteOut(
      id: '1',
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
      postalCode: '2000',
      country: 'AU',
    );
    expect(site.displayAddress, '12 Example St, Sydney, NSW, 2000, AU');
  });

  test('displayAddress falls back to name when no address parts', () {
    final site = ClientSiteOut(
      id: '1',
      tenantId: 't',
      clientId: 'c',
      name: 'Home',
      geofenceRadiusM: 100,
      isPrimary: false,
      createdAt: now,
      updatedAt: now,
    );
    expect(site.displayAddress, 'Home');
  });

  test('mapsQueryLabel prefers full address over name alone', () {
    final site = ClientSiteOut(
      id: '1',
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
    expect(site.mapsQueryLabel, contains('12 Example St'));
  });
}
