import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';

void main() {
  group('ClientContactOut', () {
    test('parses relationship from JSON', () {
      final contact = ClientContactOut.fromJson({
        'id': 'c1',
        'tenant_id': 't1',
        'client_id': 'cl1',
        'name': 'Alex Parent',
        'email': null,
        'phone': '+61400000001',
        'is_primary': true,
        'notify_visit_complete': false,
        'relationship': 'emergency',
      });
      expect(contact.relationship, 'emergency');
      expect(contact.notifyVisitComplete, isFalse);
    });

    test('parses is_emergency from JSON', () {
      final contact = ClientContactOut.fromJson({
        'id': 'c1',
        'tenant_id': 't1',
        'client_id': 'cl1',
        'name': 'Jane Mother',
        'phone': '+61400000011',
        'is_primary': false,
        'notify_visit_complete': false,
        'relationship': 'mother',
        'is_emergency': true,
      });
      expect(contact.relationship, 'mother');
      expect(contact.isEmergency, isTrue);
    });

    test('relationship null when absent', () {
      final contact = ClientContactOut.fromJson({
        'id': 'c1',
        'tenant_id': 't1',
        'client_id': 'cl1',
        'is_primary': false,
        'notify_visit_complete': true,
      });
      expect(contact.relationship, isNull);
      expect(contact.isEmergency, isFalse);
    });
  });

  group('ClientContactWriteRequest', () {
    test('serializes relationship', () {
      const body = ClientContactWriteRequest(
        name: 'Alex',
        phone: '+61400000001',
        relationship: 'carer',
        notifyVisitComplete: false,
      );
      expect(body.toJson()['relationship'], 'carer');
      expect(body.toJson()['notify_visit_complete'], isFalse);
    });

    test('serializes is_emergency', () {
      const body = ClientContactWriteRequest(
        name: 'Jane',
        phone: '+61400000011',
        relationship: 'mother',
        isEmergency: true,
      );
      expect(body.toJson()['is_emergency'], isTrue);
      expect(body.toJson()['relationship'], 'mother');
    });

    test('omits is_emergency when unset for partial patch', () {
      const body = ClientContactWriteRequest(isEmergency: true);
      expect(body.toJson(), {'is_emergency': true});
    });
  });

  group('ClientSiteOut', () {
    test('parses access_notes from JSON', () {
      final site = ClientSiteOut.fromJson({
        'id': 's1',
        'tenant_id': 't1',
        'client_id': 'cl1',
        'name': 'Home',
        'geofence_radius_m': 100,
        'is_primary': true,
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
        'access_notes': 'Gate code 1234; side door',
      });
      expect(site.accessNotes, 'Gate code 1234; side door');
    });
  });

  group('ClientSiteWriteRequest', () {
    test('serializes access_notes', () {
      const body = ClientSiteWriteRequest(
        name: 'Home',
        latitude: -33.86,
        longitude: 151.20,
        accessNotes: 'Key under mat',
      );
      expect(body.toJson()['access_notes'], 'Key under mat');
    });
  });
}
