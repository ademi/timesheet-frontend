/// API error shape: `{ "detail": "<message>" }`.
class AuthErrorModel implements Exception {
  const AuthErrorModel({required this.detail});

  final String detail;

  @override
  String toString() => detail;

  factory AuthErrorModel.fromJson(Map<String, dynamic> json) {
    final raw = json['detail'];
    final message = raw is String
        ? raw
        : raw?.toString() ?? 'Something went wrong';
    return AuthErrorModel(detail: message);
  }

  Map<String, dynamic> toJson() => {'detail': detail};
}
