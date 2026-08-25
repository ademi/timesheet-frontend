import 'models/billing_models.dart';

class NdisCatalogueFacet {
  const NdisCatalogueFacet({required this.number, this.name});

  final String number;
  final String? name;
}

class NdisCatalogueFacets {
  const NdisCatalogueFacets({
    required this.supportCategories,
    required this.registrationGroups,
  });

  final List<NdisCatalogueFacet> supportCategories;
  final List<NdisCatalogueFacet> registrationGroups;
}

/// Pure in-memory facet + filter helpers for the session-cached catalogue.
///
/// Picker filtering is frontend-only (D20): no `/facets` HTTP and no
/// per-keystroke `searchItems`.
abstract final class NdisCatalogueLocalFilter {
  NdisCatalogueLocalFilter._();

  static NdisCatalogueFacets facets(List<NdisCatalogueItemOut> items) {
    return NdisCatalogueFacets(
      supportCategories: _distinct(
        items,
        numberOf: (item) => item.supportCategoryNumber,
        nameOf: (item) => item.supportCategoryName,
      ),
      registrationGroups: registrationGroupsFor(items),
    );
  }

  static List<NdisCatalogueFacet> registrationGroupsFor(
    List<NdisCatalogueItemOut> items,
  ) {
    return _distinct(
      items,
      numberOf: (item) => item.registrationGroupNumber,
      nameOf: (item) => item.registrationGroupName,
    );
  }

  static List<NdisCatalogueItemOut> apply(
    List<NdisCatalogueItemOut> items, {
    String? categoryNumber,
    String? registrationGroupNumber,
    String query = '',
  }) {
    final category = categoryNumber?.trim();
    final regGroup = registrationGroupNumber?.trim();
    final needle = query.trim().toLowerCase();

    return items
        .where((item) {
          if (category != null &&
              category.isNotEmpty &&
              item.supportCategoryNumber != category) {
            return false;
          }
          if (regGroup != null &&
              regGroup.isNotEmpty &&
              item.registrationGroupNumber != regGroup) {
            return false;
          }
          if (needle.isEmpty) return true;
          return item.supportItemNumber.toLowerCase().contains(needle) ||
              item.supportItemName.toLowerCase().contains(needle);
        })
        .toList(growable: false);
  }

  static List<NdisCatalogueFacet> _distinct(
    List<NdisCatalogueItemOut> items, {
    required String? Function(NdisCatalogueItemOut item) numberOf,
    required String? Function(NdisCatalogueItemOut item) nameOf,
  }) {
    final byNumber = <String, String?>{};
    for (final item in items) {
      final number = numberOf(item)?.trim();
      if (number == null || number.isEmpty) continue;
      byNumber.putIfAbsent(number, () => nameOf(item));
    }
    final numbers = byNumber.keys.toList()..sort();
    return [
      for (final number in numbers)
        NdisCatalogueFacet(number: number, name: byNumber[number]),
    ];
  }
}
