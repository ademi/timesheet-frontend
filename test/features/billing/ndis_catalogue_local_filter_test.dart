import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/billing/data/models/billing_models.dart';
import 'package:rostiq/features/billing/data/ndis_catalogue_local_filter.dart';

const sampleItems = [
  NdisCatalogueItemOut(
    supportItemNumber: '01_011_0107_1_1',
    supportItemName:
        'Assistance With Self-Care Activities - Standard - Weekday Daytime',
    supportCategoryNumber: '01',
    supportCategoryName: 'Assistance with Daily Life',
    registrationGroupNumber: '0107',
    registrationGroupName: 'Daily Personal Activities',
  ),
  NdisCatalogueItemOut(
    supportItemNumber: '01_019_0120_1_1',
    supportItemName: 'House or Yard Maintenance',
    supportCategoryNumber: '01',
    supportCategoryName: 'Assistance with Daily Life',
    registrationGroupNumber: '0120',
    registrationGroupName: 'Household Tasks',
  ),
  NdisCatalogueItemOut(
    supportItemNumber: '04_104_0125_6_1',
    supportItemName: 'Access Community Social and Rec Activities',
    supportCategoryNumber: '04',
    supportCategoryName: 'Community Participation',
    registrationGroupNumber: '0125',
    registrationGroupName:
        'Participation In Community, Social And Civic Activities',
  ),
];

void main() {
  test('deriveFacets builds distinct categories and registration groups', () {
    final facets = NdisCatalogueLocalFilter.facets(sampleItems);
    expect(facets.supportCategories.map((c) => c.number), contains('01'));
    expect(facets.supportCategories.map((c) => c.number).toSet(), {'01', '04'});
    expect(facets.registrationGroups.map((g) => g.number).toSet(), {
      '0107',
      '0120',
      '0125',
    });
    expect(
      facets.supportCategories.where((c) => c.number == '01').single.name,
      'Assistance with Daily Life',
    );
  });

  test('filter cascades reg groups when category selected', () {
    final filtered = NdisCatalogueLocalFilter.apply(
      sampleItems,
      categoryNumber: '01',
      registrationGroupNumber: null,
      query: '',
    );
    final groups = NdisCatalogueLocalFilter.registrationGroupsFor(filtered);
    expect(
      groups.every(
        (g) => filtered.any((i) => i.registrationGroupNumber == g.number),
      ),
      isTrue,
    );
    expect(groups.map((g) => g.number).toSet(), {'0107', '0120'});
    expect(groups.map((g) => g.number), isNot(contains('0125')));
    expect(filtered.every((i) => i.supportCategoryNumber == '01'), isTrue);
  });

  test('text filter is case-insensitive on code and name', () {
    final filtered = NdisCatalogueLocalFilter.apply(sampleItems, query: 'self');
    expect(filtered, isNotEmpty);
    expect(filtered.map((i) => i.supportItemNumber), ['01_011_0107_1_1']);

    final byNameCase = NdisCatalogueLocalFilter.apply(
      sampleItems,
      query: 'SELF-CARE',
    );
    expect(byNameCase.map((i) => i.supportItemNumber), ['01_011_0107_1_1']);

    final byCode = NdisCatalogueLocalFilter.apply(sampleItems, query: '01_019');
    expect(byCode.map((i) => i.supportItemNumber), ['01_019_0120_1_1']);
  });
}
