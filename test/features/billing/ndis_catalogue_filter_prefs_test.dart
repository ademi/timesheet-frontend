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

  test('prefs are keyed by tenantId and do not leak across tenants', () {
    final box = <String, dynamic>{};
    NdisCatalogueFilterPrefs prefsFor(String tenantId) =>
        NdisCatalogueFilterPrefs(
          tenantId: tenantId,
          read: (k) => box[k],
          write: (k, v) => box[k] = v,
          remove: (k) => box.remove(k),
        );

    prefsFor('tenant-a').save(
      categoryNumber: '1',
      registrationGroupNumber: '0107',
    );
    prefsFor('tenant-b').save(
      categoryNumber: '4',
      registrationGroupNumber: '0125',
    );

    expect(prefsFor('tenant-a').load().categoryNumber, '1');
    expect(prefsFor('tenant-a').load().registrationGroupNumber, '0107');
    expect(prefsFor('tenant-b').load().categoryNumber, '4');
    expect(prefsFor('tenant-b').load().registrationGroupNumber, '0125');

    prefsFor('tenant-a').clear();
    expect(prefsFor('tenant-a').load().categoryNumber, isNull);
    expect(prefsFor('tenant-b').load().categoryNumber, '4');
    expect(box.keys, contains('ndis_filter_category_tenant-b'));
    expect(box.keys, isNot(contains('ndis_filter_category_tenant-a')));
  });
}
