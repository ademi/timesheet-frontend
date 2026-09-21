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

  test('Other custom label over 120 chars is not upload-ready', () {
    final row = LegalOtherDocumentDraft(
      id: '1',
      typeKey: 'other',
      customLabel: 'x' * (legalOtherMaxCustomLabelLength + 1),
    );
    expect(row.displayLabel, isNotNull);
    expect(row.canUpload, isFalse);
  });

  test('legalOtherDocsFromFactValue hydrates complete rows', () {
    final rows = legalOtherDocsFromFactValue([
      {
        'type': 'court_order',
        'label': 'Court order',
        'document_id': 'doc-1',
      },
      {
        'type': 'other',
        'label': 'Special order',
        'document_id': 'doc-2',
      },
    ]);
    expect(rows, hasLength(2));
    expect(rows[0].typeKey, 'court_order');
    expect(rows[0].displayLabel, 'Court order');
    expect(rows[0].documentId, 'doc-1');
    expect(rows[0].complete, isTrue);
    expect(rows[1].typeKey, 'other');
    expect(rows[1].customLabel, 'Special order');
    expect(rows[1].displayLabel, 'Special order');
    expect(rows[1].documentId, 'doc-2');
  });
}
