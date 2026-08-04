// Client types, requirements, and profile DTOs (`/v1/clients/types`, `/profile`).

class ClientTypeOut {
  const ClientTypeOut({
    required this.id,
    required this.code,
    required this.name,
    required this.isActive,
    required this.sortOrder,
    this.tenantId,
    this.description,
    this.industryCode,
  });

  final String id;
  final String? tenantId;
  final String code;
  final String name;
  final String? description;
  final String? industryCode;
  final bool isActive;
  final int sortOrder;

  factory ClientTypeOut.fromJson(Map<String, dynamic> json) {
    return ClientTypeOut(
      id: json['id'].toString(),
      tenantId: json['tenant_id']?.toString(),
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      industryCode: json['industry_code'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}

class ClientTypeRequirement {
  const ClientTypeRequirement({
    required this.requirementKey,
    required this.label,
    required this.sortOrder,
    required this.kind,
    required this.captureModes,
    required this.fieldSchemaJson,
    required this.isRequired,
    this.helpText,
    this.valueType,
    this.documentCategory,
    this.legalDocKey,
    this.sensitivityClass,
  });

  final String requirementKey;
  final String label;
  final String? helpText;
  final int sortOrder;

  /// `field` | `document` | `form` | `legal` | `sharing_flag`
  final String kind;
  final List<String> captureModes;

  /// `text`, `textarea`, `date`, `number`, `boolean`, `select`, `multiselect`
  final String? valueType;
  final Map<String, dynamic> fieldSchemaJson;
  final String? documentCategory;
  final String? legalDocKey;
  final String? sensitivityClass;
  final bool isRequired;

  bool get capturesField =>
      captureModes.contains('field') || kind == 'field' || kind == 'sharing_flag';

  bool get capturesDocument =>
      captureModes.contains('document') || kind == 'document';

  bool get isDualCapture => capturesField && capturesDocument;

  bool get isForm => kind == 'form';

  bool get isLegal => kind == 'legal';

  bool get isSharingFlag =>
      kind == 'sharing_flag' || captureModes.contains('sharing_flag');

  List<String> get acceptMimeTypes {
    final raw = fieldSchemaJson['accept'];
    if (raw is List) {
      return raw.map((e) => e.toString()).toList(growable: false);
    }
    return const [];
  }

  int get maxFiles {
    final raw = fieldSchemaJson['max_files'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 1;
  }

  List<ClientFormFieldSchema> get formFields {
    final raw = fieldSchemaJson['fields'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => ClientFormFieldSchema.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  List<String> get selectOptions {
    final raw = fieldSchemaJson['options'] ?? fieldSchemaJson['choices'];
    if (raw is! List) return const [];
    return raw.map((e) {
      if (e is Map) {
        return (e['label'] ?? e['value'] ?? e['id'] ?? '').toString();
      }
      return e.toString();
    }).where((s) => s.isNotEmpty).toList(growable: false);
  }

  String? get placeholder => fieldSchemaJson['placeholder']?.toString();

  factory ClientTypeRequirement.fromJson(Map<String, dynamic> json) {
    final modes = json['capture_modes'];
    final schema = json['field_schema_json'];
    return ClientTypeRequirement(
      requirementKey: (json['requirement_key'] ?? json['key'] ?? '').toString(),
      label: json['label'] as String? ?? '',
      helpText: json['help_text'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      kind: json['kind'] as String? ?? 'field',
      captureModes: modes is List
          ? modes.map((e) => e.toString()).toList(growable: false)
          : const <String>[],
      valueType: json['value_type'] as String?,
      fieldSchemaJson: schema is Map
          ? Map<String, dynamic>.from(schema)
          : const <String, dynamic>{},
      documentCategory: json['document_category'] as String?,
      legalDocKey: json['legal_doc_key'] as String?,
      sensitivityClass: json['sensitivity_class'] as String?,
      isRequired: json['is_required'] as bool? ?? false,
    );
  }
}

class ClientFormFieldSchema {
  const ClientFormFieldSchema({
    required this.id,
    required this.type,
    required this.label,
    required this.required,
  });

  final String id;
  final String type;
  final String label;
  final bool required;

  factory ClientFormFieldSchema.fromJson(Map<String, dynamic> json) {
    return ClientFormFieldSchema(
      id: (json['id'] ?? json['key'] ?? '').toString(),
      type: json['type'] as String? ?? 'text',
      label: json['label'] as String? ?? '',
      required: json['required'] as bool? ?? false,
    );
  }
}

class ProfileFactUpsert {
  const ProfileFactUpsert({
    this.valueJson,
    this.documentId,
    this.clearValue = false,
    this.clearDocument = false,
  });

  final Object? valueJson;
  final String? documentId;
  final bool clearValue;
  final bool clearDocument;

  Map<String, dynamic> toJson() => {
        if (valueJson != null) 'value_json': valueJson,
        if (documentId != null) 'document_id': documentId,
        if (clearValue) 'clear_value': true,
        if (clearDocument) 'clear_document': true,
      };
}

class ClientLegalDocumentCurrent {
  const ClientLegalDocumentCurrent({
    required this.id,
    required this.title,
    required this.contentMd,
    this.docKey,
    this.version,
    this.counselPending = false,
  });

  final String id;
  final String title;
  final String contentMd;
  final String? docKey;
  final String? version;
  final bool counselPending;

  factory ClientLegalDocumentCurrent.fromJson(Map<String, dynamic> json) {
    return ClientLegalDocumentCurrent(
      id: (json['id'] ??
              json['legal_document_version_id'] ??
              json['version_id'] ??
              '')
          .toString(),
      title: json['title'] as String? ?? json['doc_key']?.toString() ?? 'Consent',
      contentMd: json['content_md'] as String? ?? '',
      docKey: json['doc_key'] as String?,
      version: json['version']?.toString(),
      counselPending: json['counsel_pending'] as bool? ?? false,
    );
  }
}

class ClientLegalAcceptRequest {
  const ClientLegalAcceptRequest({
    required this.eventType,
    required this.legalDocumentVersionId,
    required this.participantOrRepName,
    required this.method,
    this.relationship,
    this.signedAt,
    this.note,
  });

  final String eventType;
  final String legalDocumentVersionId;
  final String participantOrRepName;
  final String? relationship;
  final String method;
  final DateTime? signedAt;
  final String? note;

  Map<String, dynamic> toJson() => {
        'event_type': eventType,
        'legal_document_version_id': legalDocumentVersionId,
        'participant_or_rep_name': participantOrRepName,
        if (relationship != null && relationship!.isNotEmpty)
          'relationship': relationship,
        'method': method,
        'signed_at': (signedAt ?? DateTime.now().toUtc()).toIso8601String(),
        if (note != null) 'note': note,
      };
}

class ClientFormSubmitRequest {
  const ClientFormSubmitRequest({
    required this.status,
    required this.payloadJson,
  });

  final String status;
  final Map<String, dynamic> payloadJson;

  Map<String, dynamic> toJson() => {
        'status': status,
        'payload_json': payloadJson,
      };
}

class ClientProfileFactOut {
  const ClientProfileFactOut({
    required this.requirementKey,
    this.valueJson,
    this.documentId,
  });

  final String requirementKey;
  final Object? valueJson;
  final String? documentId;

  factory ClientProfileFactOut.fromJson(Map<String, dynamic> json) {
    return ClientProfileFactOut(
      requirementKey:
          (json['requirement_key'] ?? json['key'] ?? '').toString(),
      valueJson: json['value_json'],
      documentId: json['document_id']?.toString(),
    );
  }
}

class ClientFormSubmissionOut {
  const ClientFormSubmissionOut({
    required this.requirementKey,
    required this.status,
    required this.payloadJson,
  });

  final String requirementKey;
  final String status;
  final Map<String, dynamic> payloadJson;

  factory ClientFormSubmissionOut.fromJson(Map<String, dynamic> json) {
    final payload = json['payload_json'];
    return ClientFormSubmissionOut(
      requirementKey: (json['requirement_key'] ??
              json['form_key'] ??
              json['key'] ??
              '')
          .toString(),
      status: json['status'] as String? ?? 'submitted',
      payloadJson: payload is Map
          ? Map<String, dynamic>.from(payload)
          : const <String, dynamic>{},
    );
  }
}

class ClientLegalAcceptanceOut {
  const ClientLegalAcceptanceOut({
    required this.requirementKey,
    this.eventType,
    this.legalDocumentVersionId,
    this.participantOrRepName,
    this.relationship,
    this.method,
  });

  final String requirementKey;
  final String? eventType;
  final String? legalDocumentVersionId;
  final String? participantOrRepName;
  final String? relationship;
  final String? method;

  factory ClientLegalAcceptanceOut.fromJson(Map<String, dynamic> json) {
    return ClientLegalAcceptanceOut(
      requirementKey: (json['requirement_key'] ??
              json['legal_key'] ??
              json['key'] ??
              '')
          .toString(),
      eventType: json['event_type'] as String?,
      legalDocumentVersionId:
          json['legal_document_version_id']?.toString(),
      participantOrRepName: json['participant_or_rep_name'] as String?,
      relationship: json['relationship'] as String?,
      method: json['method'] as String?,
    );
  }
}

class ClientProfileBundle {
  const ClientProfileBundle({
    this.clientType,
    this.requirements = const [],
    this.facts = const [],
    this.formSubmissions = const [],
    this.legalAcceptances = const [],
    this.readiness,
  });

  final ClientTypeOut? clientType;
  final List<ClientTypeRequirement> requirements;
  final List<ClientProfileFactOut> facts;
  final List<ClientFormSubmissionOut> formSubmissions;
  final List<ClientLegalAcceptanceOut> legalAcceptances;
  final Map<String, dynamic>? readiness;

  factory ClientProfileBundle.fromJson(Map<String, dynamic> json) {
    final typeRaw = json['client_type'];
    final reqs = json['requirements'];
    final facts = json['facts'];
    final forms = json['form_submissions'];
    final legal = json['legal_acceptances'];
    final readiness = json['readiness'];
    return ClientProfileBundle(
      clientType: typeRaw is Map
          ? ClientTypeOut.fromJson(Map<String, dynamic>.from(typeRaw))
          : null,
      requirements: _mapList(reqs, ClientTypeRequirement.fromJson),
      facts: _mapList(facts, ClientProfileFactOut.fromJson),
      formSubmissions: _mapList(forms, ClientFormSubmissionOut.fromJson),
      legalAcceptances: _mapList(legal, ClientLegalAcceptanceOut.fromJson),
      readiness: readiness is Map
          ? Map<String, dynamic>.from(readiness)
          : null,
    );
  }
}

List<T> _mapList<T>(
  dynamic raw,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => fromJson(Map<String, dynamic>.from(e)))
      .toList(growable: false);
}

/// Local file held until client exists and upload can run.
class PickedClientFile {
  const PickedClientFile({
    required this.name,
    required this.contentType,
    required this.bytes,
  });

  final String name;
  final String contentType;
  final List<int> bytes;
}
