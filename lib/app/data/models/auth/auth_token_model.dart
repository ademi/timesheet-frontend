class AuthTokenModel {
  const AuthTokenModel({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    this.mustChangePassword = false,
    this.defaultBranchId,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final bool mustChangePassword;
  final String? defaultBranchId;

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'token_type': tokenType,
      };

  factory AuthTokenModel.fromJson(Map<String, dynamic> json) {
    return AuthTokenModel(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
      mustChangePassword: json['must_change_password'] as bool? ?? false,
      defaultBranchId: json['branch_id'] as String?,
    );
  }
}
