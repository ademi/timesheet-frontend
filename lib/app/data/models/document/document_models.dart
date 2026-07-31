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
      documentId: json['document_id'].toString(),
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
    this.credentialId,
    this.verificationStatus,
    this.createdAt,
  });

  final String id;
  final String ownerType;
  final String ownerId;
  final String filename;
  final String contentType;
  final int sizeBytes;
  final String scanStatus;
  final String? category;
  final String? credentialId;
  final String? verificationStatus;
  final DateTime? createdAt;

  bool get isScanPending => scanStatus == 'pending' || scanStatus == 'scanning';

  bool get isScanClean => scanStatus == 'clean';

  bool get isScanBlocked => scanStatus == 'blocked';

  factory DocumentOut.fromJson(Map<String, dynamic> json) {
    return DocumentOut(
      id: json['id'].toString(),
      ownerType: json['owner_type'] as String,
      ownerId: json['owner_id'].toString(),
      filename: json['filename'] as String,
      contentType: json['content_type'] as String,
      sizeBytes: json['size_bytes'] as int,
      scanStatus: json['scan_status'] as String? ?? 'pending',
      category: json['category'] as String?,
      credentialId: json['credential_id'] as String?,
      verificationStatus: json['verification_status'] as String?,
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString())
              : null,
    );
  }
}

class DownloadUrlResponse {
  const DownloadUrlResponse({
    required this.downloadUrl,
    required this.expiresInSeconds,
  });

  final String downloadUrl;
  final int expiresInSeconds;

  factory DownloadUrlResponse.fromJson(Map<String, dynamic> json) {
    return DownloadUrlResponse(
      downloadUrl:
          (json['download_url'] as String?) ?? (json['url'] as String?) ?? '',
      expiresInSeconds: json['expires_in_seconds'] as int? ?? 0,
    );
  }
}
