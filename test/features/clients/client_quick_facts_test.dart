import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/clients/data/models/client_profile_models.dart';
import 'package:rostiq/features/clients/utils/client_quick_facts.dart';

void main() {
  test('isPatientClientType matches name or code', () {
    expect(
      isPatientClientType(typeName: 'Patient', typeCode: 'other'),
      isTrue,
    );
    expect(
      isPatientClientType(typeName: 'Organisation', typeCode: 'patient'),
      isTrue,
    );
    expect(
      isPatientClientType(typeName: 'Organisation', typeCode: 'org'),
      isFalse,
    );
  });

  test('ndisFromFacts reads ndis requirement', () {
    final facts = [
      const ClientProfileFactOut(requirementKey: 'ndis', valueJson: '430000000'),
    ];
    expect(ndisFromFacts(facts), '430000000');
  });
}
