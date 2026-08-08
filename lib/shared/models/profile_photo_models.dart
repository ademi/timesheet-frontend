/// Shared profile-photo DTOs for contractor-me and client endpoints.
class ProfilePhotoOut {
  const ProfilePhotoOut({
    this.documentId,
    this.downloadUrl,
    this.expiresInSeconds,
    this.hasPhoto = false,
  });

  final String? documentId;
  final String? downloadUrl;
  final int? expiresInSeconds;
  final bool hasPhoto;

  factory ProfilePhotoOut.fromJson(Map<String, dynamic> json) {
    return ProfilePhotoOut(
      documentId: json['document_id']?.toString(),
      downloadUrl: json['download_url'] as String?,
      expiresInSeconds: json['expires_in_seconds'] as int?,
      hasPhoto: json['has_photo'] as bool? ??
          (json['document_id'] != null || json['download_url'] != null),
    );
  }

  bool get hasDisplayableUrl =>
      downloadUrl != null && downloadUrl!.trim().isNotEmpty;
}

class ProfilePhotoSetRequest {
  const ProfilePhotoSetRequest({required this.documentId});

  final String documentId;

  Map<String, dynamic> toJson() => {'document_id': documentId};
}

class PickedProfilePhoto {
  const PickedProfilePhoto({
    required this.name,
    required this.contentType,
    required this.bytes,
  });

  final String name;
  final String contentType;
  final List<int> bytes;
}
