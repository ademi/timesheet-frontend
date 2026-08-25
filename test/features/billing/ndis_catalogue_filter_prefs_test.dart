import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/billing/data/ndis_catalogue_filter_prefs.dart';

void main() {
  test('NdisCatalogueFilterPrefs round-trips category and registration group', () {
    final box = <String, dynamic>{};
    final prefs = NdisCatalogueFilterPrefs(
      read: (k) => box[k],
      write: (k, v) => box[k] = v,
      remove: (k) => box.remove(k),
    );
    prefs.save(categoryNumber: '01', registrationGroupNumber: '0107');
    expect(prefs.load().categoryNumber, '01');
    expect(prefs.load().registrationGroupNumber, '0107');
  });

  test('save with null values clears stored keys', () {
    final box = <String, dynamic>{};
    final prefs = NdisCatalogueFilterPrefs(
      read: (k) => box[k],
      write: (k, v) => box[k] = v,
      remove: (k) => box.remove(k),
    );
    prefs.save(categoryNumber: '1', registrationGroupNumber: '0107');
    prefs.save(categoryNumber: null, registrationGroupNumber: null);
    expect(box, isEmpty);
    expect(prefs.load().categoryNumber, isNull);
    expect(prefs.load().registrationGroupNumber, isNull);
  });

  test('clear removes both filter keys', () {
    final box = <String, dynamic>{};
    final prefs = NdisCatalogueFilterPrefs(
      read: (k) => box[k],
      write: (k, v) => box[k] = v,
      remove: (k) => box.remove(k),
    );
    prefs.save(categoryNumber: '4', registrationGroupNumber: '0125');
    prefs.clear();
    expect(box, isEmpty);
  });
}
