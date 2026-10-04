import 'models/billing_models.dart';
import 'legacy_sta.dart';

/// Catalogue hygiene helpers for publish / draft remaps (B13 MVP).
abstract final class CatalogueHygiene {
  CatalogueHygiene._();

  /// True when [code] is absent from the active catalogue map.
  static bool isMissingFromCatalogue(
    String? code,
    Map<String, NdisCatalogueItemOut> catalogueByCode,
  ) {
    final c = code?.trim();
    if (c == null || c.isEmpty) return false;
    return !catalogueByCode.containsKey(c);
  }

  /// Clear-and-warn when job/draft code is legacy STA or not in active catalogue.
  static CatalogueHygieneResult sanitizeSelection({
    required String? code,
    required String? name,
    required Map<String, NdisCatalogueItemOut> catalogueByCode,
  }) {
    final c = code?.trim();
    if (c == null || c.isEmpty) {
      return const CatalogueHygieneResult();
    }
    if (LegacyStaRatio.isLegacyStaRatioItem(code: c, name: name)) {
      return const CatalogueHygieneResult(
        clearSelection: true,
        warning:
            'Job support item is a legacy STA ratio package. '
            'Pick an unbundled item before publish.',
      );
    }
    if (isMissingFromCatalogue(c, catalogueByCode)) {
      return CatalogueHygieneResult(
        clearSelection: true,
        warning:
            'Job support item $c is not in the active catalogue. '
            'Pick a current item before publish.',
      );
    }
    final catalogued = catalogueByCode[c]!;
    return CatalogueHygieneResult(
      code: c,
      name: (name?.trim().isNotEmpty == true)
          ? name!.trim()
          : catalogued.supportItemName,
    );
  }

  /// First suggested code present in the active catalogue (shift-kind auto-map).
  static NdisCatalogueItemOut? firstSuggestedInCatalogue({
    required List<String> suggestedCodes,
    required Map<String, NdisCatalogueItemOut> catalogueByCode,
  }) {
    for (final raw in suggestedCodes) {
      final code = raw.trim();
      if (code.isEmpty) continue;
      if (LegacyStaRatio.isLegacyStaRatioItem(code: code)) continue;
      final item = catalogueByCode[code];
      if (item != null) return item;
    }
    return null;
  }
}

class CatalogueHygieneResult {
  const CatalogueHygieneResult({
    this.code,
    this.name,
    this.clearSelection = false,
    this.warning,
  });

  final String? code;
  final String? name;
  final bool clearSelection;
  final String? warning;
}
