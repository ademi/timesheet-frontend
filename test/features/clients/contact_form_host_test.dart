import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/clients/widgets/contact_form_host.dart';

void main() {
  test('hydrateRelationship maps Emergency contact free-text to Other (I4)', () {
    final hydrated = ContactFormHost.hydrateRelationship('Emergency contact');
    expect(hydrated.preset, ContactFormHost.relationshipOtherKey);
    expect(hydrated.otherText, 'Emergency contact');
  });

  test('hydrateRelationship maps kinship keys to presets', () {
    final hydrated = ContactFormHost.hydrateRelationship('mother');
    expect(hydrated.preset, 'mother');
    expect(hydrated.otherText, '');
  });
}
