/// API error shape: `{ "detail": "<message>" }` or structured `{ "detail": { "message", "code" } }`.
class AuthErrorModel implements Exception {
  const AuthErrorModel({required this.detail, this.code});

  final String detail;
  final String? code;

  bool get isPinNotSet => code == 'pin_not_set';

  @override
  String toString() => detail;

  factory AuthErrorModel.fromJson(Map<String, dynamic> json) {
    final raw = json['detail'];
    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);
      return AuthErrorModel(
        detail: m['message'] as String? ??
            m['code'] as String? ??
            'Something went wrong',
        code: m['code'] as String?,
      );
    }
    if (raw is String) {
      return AuthErrorModel(detail: raw, code: json['code'] as String?);
    }
    // Public API paths often return `{ "message": "..." }` instead of detail.
    final publicMessage = json['message'];
    if (publicMessage is String && publicMessage.isNotEmpty) {
      return AuthErrorModel(
        detail: publicMessage,
        code: json['code'] as String?,
      );
    }
    final message = raw?.toString() ?? 'Something went wrong';
    return AuthErrorModel(detail: message, code: json['code'] as String?);
  }

  Map<String, dynamic> toJson() => {
        if (code != null) 'code': code,
        'detail': detail,
      };
}
