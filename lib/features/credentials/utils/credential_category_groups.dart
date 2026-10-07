import '../data/models/credential_models.dart';

/// One display section of credential / required-document types.
class CredentialCategoryGroup {
  const CredentialCategoryGroup({
    required this.title,
    required this.items,
  });

  final String title;
  final List<CredentialCategory> items;
}

/// Stable section order for invite / required-doc pickers.
const credentialCategoryGroupOrder = <String>[
  'Identity',
  'Screening & checks',
  'Training & certifications',
  'Qualifications',
  'Vehicle & insurance',
  'Other',
];

/// FE fallback when catalog omits [CredentialCategory.group].
const credentialCategoryGroupByCode = <String, String>{
  'passport_id': 'Identity',
  'drivers_licence': 'Identity',
  'ndis_worker_screening': 'Screening & checks',
  'police_check': 'Screening & checks',
  'wwcc': 'Screening & checks',
  'first_aid': 'Training & certifications',
  'cpr': 'Training & certifications',
  'infection_control': 'Training & certifications',
  'worker_orientation': 'Training & certifications',
  'ndis_induction': 'Training & certifications',
  'effective_communication': 'Training & certifications',
  'medication_admin': 'Training & certifications',
  'epilepsy_management': 'Training & certifications',
  'manual_handling': 'Training & certifications',
  'resume': 'Qualifications',
  'cert_iii': 'Qualifications',
  'nursing_bachelor': 'Qualifications',
  'nursing_diploma': 'Qualifications',
  'other_health_qualification': 'Qualifications',
  'trade_certificate': 'Qualifications',
  'vehicle_registration': 'Vehicle & insurance',
  'insurance': 'Vehicle & insurance',
  'abn': 'Other',
  'other': 'Other',
};

String credentialCategoryGroupTitle(CredentialCategory category) {
  final fromApi = category.group?.trim();
  if (fromApi != null && fromApi.isNotEmpty) return fromApi;
  return credentialCategoryGroupByCode[category.code] ?? 'Other';
}

/// Groups [categories] under section titles; items sorted by label within each.
List<CredentialCategoryGroup> groupCredentialCategories(
  Iterable<CredentialCategory> categories,
) {
  final buckets = <String, List<CredentialCategory>>{};
  for (final cat in categories) {
    final title = credentialCategoryGroupTitle(cat);
    buckets.putIfAbsent(title, () => []).add(cat);
  }

  for (final list in buckets.values) {
    list.sort(
      (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
    );
  }

  final out = <CredentialCategoryGroup>[];
  final seen = <String>{};

  for (final title in credentialCategoryGroupOrder) {
    final items = buckets[title];
    if (items == null || items.isEmpty) continue;
    out.add(CredentialCategoryGroup(title: title, items: items));
    seen.add(title);
  }

  final extras =
      buckets.keys.where((k) => !seen.contains(k)).toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  for (final title in extras) {
    out.add(CredentialCategoryGroup(title: title, items: buckets[title]!));
  }

  return out;
}
