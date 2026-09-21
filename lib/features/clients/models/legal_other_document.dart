import 'dart:convert';

/// Preset type keys for optional legal "other" document rows on the Legal step.
const legalOtherTypePresets = <String, String>{
  'guardianship_order': 'Guardianship order',
  'court_order': 'Court order',
  'power_of_attorney': 'Power of attorney',
  'other': 'Other',
};

/// Max trimmed length for Other custom labels (upload/persist validation).
const legalOtherMaxCustomLabelLength = 120;

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

  bool get canUpload {
    final label = displayLabel;
    if (label == null) return false;
    if (typeKey == 'other' && label.length > legalOtherMaxCustomLabelLength) {
      return false;
    }
    return true;
  }

  Map<String, dynamic> toFactEntry() => {
    'type': typeKey,
    'label': displayLabel ?? fileName ?? typeKey,
    'document_id': documentId,
  };
}

/// Decode [legal_other_documents] profile fact JSON into draft rows.
List<LegalOtherDocumentDraft> legalOtherDocsFromFactValue(Object? valueJson) {
  if (valueJson == null) return const [];
  List<dynamic>? rawList;
  if (valueJson is List) {
    rawList = valueJson;
  } else if (valueJson is String) {
    try {
      final decoded = jsonDecode(valueJson);
      if (decoded is List) rawList = decoded;
    } catch (_) {
      return const [];
    }
  }
  if (rawList == null) return const [];

  final out = <LegalOtherDocumentDraft>[];
  for (final item in rawList) {
    if (item is! Map) continue;
    final map = Map<String, dynamic>.from(item);
    final type = (map['type'] ?? '').toString().trim();
    if (type.isEmpty) continue;
    final label = map['label']?.toString();
    final docId = map['document_id']?.toString().trim();
    if (docId == null || docId.isEmpty) continue;
    out.add(
      LegalOtherDocumentDraft(
        id: LegalOtherDocumentDraft.nextId(),
        typeKey: type,
        customLabel: type == 'other' ? label : null,
        documentId: docId,
        complete: true,
      ),
    );
  }
  return out;
}
