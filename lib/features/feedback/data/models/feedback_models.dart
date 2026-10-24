/// In-app pilot feedback (`POST/GET /v1/feedback`).
class FeedbackCreateRequest {
  const FeedbackCreateRequest({
    required this.message,
    this.screenRoute,
    this.severity,
    this.tag,
    this.roleLabel,
  });

  final String message;
  final String? screenRoute;
  final String? severity;
  final String? tag;
  final String? roleLabel;

  Map<String, dynamic> toJson() => {
    'message': message,
    if (screenRoute != null && screenRoute!.isNotEmpty)
      'screen_route': screenRoute,
    if (severity != null && severity!.isNotEmpty) 'severity': severity,
    if (tag != null && tag!.isNotEmpty) 'tag': tag,
    if (roleLabel != null && roleLabel!.isNotEmpty) 'role_label': roleLabel,
  };
}

class FeedbackOut {
  const FeedbackOut({
    required this.id,
    required this.message,
    required this.createdAt,
    this.screenRoute,
    this.severity,
    this.tag,
    this.roleLabel,
    this.actorType,
  });

  final String id;
  final String message;
  final DateTime createdAt;
  final String? screenRoute;
  final String? severity;
  final String? tag;
  final String? roleLabel;
  final String? actorType;

  factory FeedbackOut.fromJson(Map<String, dynamic> json) {
    return FeedbackOut(
      id: json['id'].toString(),
      message: json['message'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      screenRoute: json['screen_route'] as String?,
      severity: json['severity'] as String?,
      tag: json['tag'] as String?,
      roleLabel: json['role_label'] as String?,
      actorType: json['actor_type'] as String?,
    );
  }
}
