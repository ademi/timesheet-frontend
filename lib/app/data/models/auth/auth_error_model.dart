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
    final message = raw is String
        ? raw
        : raw?.toString() ?? 'Something went wrong';
    return AuthErrorModel(detail: message);
  }

  Map<String, dynamic> toJson() => {
        if (code != null) 'code': code,
        'detail': detail,
      };
}
