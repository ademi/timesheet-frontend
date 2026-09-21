/// Preset type keys for optional legal "other" document rows on the Legal step.
const legalOtherTypePresets = <String, String>{
  'guardianship_order': 'Guardianship order',
  'court_order': 'Court order',
  'power_of_attorney': 'Power of attorney',
  'other': 'Other',
};

/// In-memory row for an optional legal document (upload/persist in later tasks).
class LegalOtherDocumentDraft {
  LegalOtherDocumentDraft({
    required this.id,
    required this.typeKey,
    this.customLabel,
    this.documentId,
    this.fileName,
    this.complete = false,
  });

  static int _idSeq = 0;

  /// Same microsecond + sequence pattern as [SupportPlanSpecialistEntry].
  static String nextId() =>
      'legal-other-${DateTime.now().microsecondsSinceEpoch}-${++_idSeq}';

  final String id;
  String typeKey;
  String? customLabel;
  String? documentId;
  String? fileName;
  bool complete;

  String? get displayLabel {
    if (typeKey == 'other') {
      final t = customLabel?.trim() ?? '';
      return t.isEmpty ? null : t;
    }
    return legalOtherTypePresets[typeKey];
  }

  bool get canUpload => displayLabel != null;
}
