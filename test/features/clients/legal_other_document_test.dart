import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/clients/models/legal_other_document.dart';

void main() {
  test('Other type requires non-empty custom label to be complete-ready', () {
    final row = LegalOtherDocumentDraft(
      id: '1',
      typeKey: 'other',
      customLabel: '  ',
    );
    expect(row.displayLabel, isNull);
    expect(row.canUpload, isFalse);
  });

  test('preset type uses catalog label', () {
    final row = LegalOtherDocumentDraft(
      id: '1',
      typeKey: 'guardianship_order',
      customLabel: null,
    );
    expect(row.displayLabel, 'Guardianship order');
  });

  test('Other with trimmed label is upload-ready', () {
    final row = LegalOtherDocumentDraft(
      id: '1',
      typeKey: 'other',
      customLabel: '  Custom doc  ',
    );
    expect(row.displayLabel, 'Custom doc');
    expect(row.canUpload, isTrue);
  });

  test('legalOtherTypePresets includes locked keys', () {
    expect(
      legalOtherTypePresets.keys,
      containsAll([
        'guardianship_order',
        'court_order',
        'power_of_attorney',
        'other',
      ]),
    );
  });
}
