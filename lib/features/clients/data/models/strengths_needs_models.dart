import '../../utils/strengths_needs_keys.dart';

class StrengthsNeedsHeader {
  const StrengthsNeedsHeader({
    this.completedBy = '',
    this.participantName = '',
    this.supportersNames = '',
    this.interviewDate,
    this.preferencesNotes = '',
  });

  final String completedBy;
  final String participantName;
  final String supportersNames;
  final String? interviewDate;
  final String preferencesNotes;

  factory StrengthsNeedsHeader.fromJson(Map<String, dynamic>? json) {
    final m = json ?? const <String, dynamic>{};
    return StrengthsNeedsHeader(
      completedBy: m['completed_by'] as String? ?? '',
      participantName: m['participant_name'] as String? ?? '',
      supportersNames: m['supporters_names'] as String? ?? '',
      interviewDate: m['interview_date'] as String?,
      preferencesNotes: m['preferences_notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'completed_by': completedBy,
        'participant_name': participantName,
        'supporters_names': supportersNames,
        if (interviewDate != null && interviewDate!.isNotEmpty)
          'interview_date': interviewDate,
        'preferences_notes': preferencesNotes,
      };
}

class StrengthsNeedsBody {
  const StrengthsNeedsBody({
    this.header = const StrengthsNeedsHeader(),
    this.sections = const {},
    this.additionalNotes = '',
  });

  final StrengthsNeedsHeader header;
  final Map<String, String> sections;
  final String additionalNotes;

  factory StrengthsNeedsBody.fromJson(Map<String, dynamic>? json) {
    final m = json ?? const <String, dynamic>{};
    final rawSections = m['sections'] as Map<String, dynamic>? ?? const {};
    final sections = <String, String>{};
    for (final key in StrengthsNeedsKeys.allSectionKeys) {
      sections[key] = rawSections[key] as String? ?? '';
    }
    return StrengthsNeedsBody(
      header: StrengthsNeedsHeader.fromJson(
        m['header'] as Map<String, dynamic>?,
      ),
      sections: sections,
      additionalNotes: m['additional_notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'header': header.toJson(),
        'sections': {
          for (final key in StrengthsNeedsKeys.allSectionKeys)
            key: sections[key] ?? '',
        },
        'additional_notes': additionalNotes,
      };
}

class StrengthsNeedsDto {
  const StrengthsNeedsDto({
    required this.id,
    required this.clientId,
    required this.status,
    required this.isCurrent,
    required this.body,
    this.preparedByUserId,
    this.submittedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String clientId;
  final String status;
  final bool isCurrent;
  final StrengthsNeedsBody body;
  final String? preparedByUserId;
  final DateTime? submittedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory StrengthsNeedsDto.fromJson(Map<String, dynamic> json) {
    return StrengthsNeedsDto(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      status: json['status'] as String,
      isCurrent: json['is_current'] as bool? ?? false,
      body: StrengthsNeedsBody.fromJson(json['body'] as Map<String, dynamic>?),
      preparedByUserId: json['prepared_by_user_id'] as String?,
      submittedAt: _parseOptionalDate(json['submitted_at']),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class StrengthsNeedsCreateRequest {
  const StrengthsNeedsCreateRequest({required this.body});

  final StrengthsNeedsBody body;

  Map<String, dynamic> toJson() => {'body': body.toJson()};
}

class StrengthsNeedsUpdateRequest {
  const StrengthsNeedsUpdateRequest({this.body});

  final StrengthsNeedsBody? body;

  Map<String, dynamic> toJson() => {
        if (body != null) 'body': body!.toJson(),
      };
}

class SnImportRequest {
  const SnImportRequest({this.sectionKeys});

  final List<String>? sectionKeys;

  Map<String, dynamic> toJson() => {
        if (sectionKeys != null) 'section_keys': sectionKeys,
      };
}

DateTime? _parseOptionalDate(Object? raw) {
  if (raw == null) return null;
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.parse(raw);
}
