import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/billing/data/catalogue_hygiene.dart';
import 'package:rostiq/features/billing/data/legacy_sta.dart';
import 'package:rostiq/features/billing/data/models/billing_models.dart';

void main() {
  test('LegacyStaRatio detects codes and names', () {
    expect(
      LegacyStaRatio.isLegacyStaRatioItem(code: '01_054_0115_1_1'),
      isTrue,
    );
    expect(
      LegacyStaRatio.isLegacyStaRatioItem(
        name: 'STA And Assistance (Inc. Respite) - 1:2 - Weekday',
      ),
      isTrue,
    );
    expect(
      LegacyStaRatio.isLegacyStaRatioItem(code: '01_011_0107_1_1'),
      isFalse,
    );
  });

  test('sanitizeSelection clears legacy and missing codes', () {
    final catalogue = {
      '01_011_0107_1_1': const NdisCatalogueItemOut(
        supportItemNumber: '01_011_0107_1_1',
        supportItemName: 'Self-Care',
      ),
    };
    final legacy = CatalogueHygiene.sanitizeSelection(
      code: '01_054_0115_1_1',
      name: 'STA And Assistance (Inc. Respite) - 1:2',
      catalogueByCode: catalogue,
    );
    expect(legacy.clearSelection, isTrue);
    expect(legacy.warning, contains('legacy STA'));

    final missing = CatalogueHygiene.sanitizeSelection(
      code: '01_999_9999_9_9',
      name: 'Gone',
      catalogueByCode: catalogue,
    );
    expect(missing.clearSelection, isTrue);
    expect(missing.warning, contains('not in the active catalogue'));

    final ok = CatalogueHygiene.sanitizeSelection(
      code: '01_011_0107_1_1',
      name: null,
      catalogueByCode: catalogue,
    );
    expect(ok.clearSelection, isFalse);
    expect(ok.code, '01_011_0107_1_1');
    expect(ok.name, 'Self-Care');
  });

  test('firstSuggestedInCatalogue skips missing and legacy', () {
    final catalogue = {
      '01_010_0107_1_1': const NdisCatalogueItemOut(
        supportItemNumber: '01_010_0107_1_1',
        supportItemName: 'Sleepover',
      ),
    };
    final item = CatalogueHygiene.firstSuggestedInCatalogue(
      suggestedCodes: const [
        '01_054_0115_1_1',
        '01_999_9999_9_9',
        '01_010_0107_1_1',
      ],
      catalogueByCode: catalogue,
    );
    expect(item?.supportItemNumber, '01_010_0107_1_1');
  });
}
