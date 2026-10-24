/// Bulk CSV import preview/commit (`POST /v1/imports/...`).
enum ImportKind { participants, workers }

extension ImportKindApi on ImportKind {
  String get apiValue => switch (this) {
    ImportKind.participants => 'participants',
    ImportKind.workers => 'workers',
  };

  String get title => switch (this) {
    ImportKind.participants => 'Import participants',
    ImportKind.workers => 'Import support workers',
  };

  String get sampleHint => switch (this) {
    ImportKind.participants =>
      'Columns: full_name (required), email, phone, dob (YYYY-MM-DD), status',
    ImportKind.workers =>
      'Columns: email (required), phone, document_pack — max 100 rows',
  };
}

class ImportCsvRequest {
  const ImportCsvRequest({required this.csv});

  final String csv;

  Map<String, dynamic> toJson() => {'csv': csv};
}

class ImportRowOut {
  const ImportRowOut({
    required this.rowNumber,
    required this.ok,
    required this.errors,
    this.preview,
    this.entityId,
  });

  final int rowNumber;
  final bool ok;
  final List<String> errors;
  final Map<String, dynamic>? preview;
  final String? entityId;

  factory ImportRowOut.fromJson(Map<String, dynamic> json) {
    final errorsRaw = json['errors'];
    final previewRaw = json['preview'];
    return ImportRowOut(
      rowNumber: (json['row_number'] as num?)?.toInt() ?? 0,
      ok: json['ok'] as bool? ?? false,
      errors:
          errorsRaw is List
              ? errorsRaw.map((e) => e.toString()).toList(growable: false)
              : const [],
      preview:
          previewRaw is Map
              ? Map<String, dynamic>.from(previewRaw)
              : null,
      entityId: json['entity_id']?.toString(),
    );
  }
}

class ImportReportOut {
  const ImportReportOut({
    required this.kind,
    required this.rowCount,
    required this.validCount,
    required this.errorCount,
    required this.rows,
    this.createdCount,
  });

  final String kind;
  final int rowCount;
  final int validCount;
  final int errorCount;
  final int? createdCount;
  final List<ImportRowOut> rows;

  factory ImportReportOut.fromJson(Map<String, dynamic> json) {
    final rowsRaw = json['rows'];
    return ImportReportOut(
      kind: json['kind'] as String? ?? '',
      rowCount: (json['row_count'] as num?)?.toInt() ?? 0,
      validCount: (json['valid_count'] as num?)?.toInt() ?? 0,
      errorCount: (json['error_count'] as num?)?.toInt() ?? 0,
      createdCount: (json['created_count'] as num?)?.toInt(),
      rows:
          rowsRaw is List
              ? rowsRaw
                  .whereType<Map>()
                  .map(
                    (e) => ImportRowOut.fromJson(Map<String, dynamic>.from(e)),
                  )
                  .toList(growable: false)
              : const [],
    );
  }
}
