class UploadUrlRequest {
  const UploadUrlRequest({
    required this.ownerType,
    required this.ownerId,
    required this.filename,
    required this.contentType,
    required this.sizeBytes,
    this.category,
  });

  final String ownerType;
  final String ownerId;
  final String filename;
  final String contentType;
  final int sizeBytes;
  final String? category;

  Map<String, dynamic> toJson() => {
        'owner_type': ownerType,
        'owner_id': ownerId,
        'filename': filename,
        'content_type': contentType,
        'size_bytes': sizeBytes,
        if (category != null) 'category': category,
      };
}

class UploadUrlResponse {
  const UploadUrlResponse({
    required this.documentId,
    required this.uploadUrl,
    required this.gcsObjectKey,
    required this.expiresInSeconds,
  });

  final String documentId;
  final String uploadUrl;
  final String gcsObjectKey;
  final int expiresInSeconds;

  factory UploadUrlResponse.fromJson(Map<String, dynamic> json) {
    return UploadUrlResponse(
      documentId: json['document_id'] as String,
      uploadUrl: json['upload_url'] as String,
      gcsObjectKey: json['gcs_object_key'] as String,
      expiresInSeconds: json['expires_in_seconds'] as int,
    );
  }
}

class DocumentOut {
  const DocumentOut({
    required this.id,
    required this.ownerType,
    required this.ownerId,
    required this.filename,
    required this.contentType,
    required this.sizeBytes,
    required this.scanStatus,
    this.category,
  });

  final String id;
  final String ownerType;
  final String ownerId;
  final String filename;
  final String contentType;
  final int sizeBytes;
  final String scanStatus;
  final String? category;

  factory DocumentOut.fromJson(Map<String, dynamic> json) {
    return DocumentOut(
      id: json['id'] as String,
      ownerType: json['owner_type'] as String,
      ownerId: json['owner_id'] as String,
      filename: json['filename'] as String,
      contentType: json['content_type'] as String,
      sizeBytes: json['size_bytes'] as int,
      scanStatus: json['scan_status'] as String,
      category: json['category'] as String?,
    );
  }
}
