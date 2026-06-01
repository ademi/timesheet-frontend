class LoginRequestModel {
  const LoginRequestModel({
    required this.identifier,
    required this.password,
    required this.tenantId,
  });

  final String identifier;
  final String password;
  final String tenantId;

  Map<String, dynamic> toJson() => {
        'identifier': identifier,
        'password': password,
        'tenant_id': tenantId,
      };

  factory LoginRequestModel.fromJson(Map<String, dynamic> json) {
    return LoginRequestModel(
      identifier: json['identifier'] as String,
      password: json['password'] as String,
      tenantId: json['tenant_id'] as String,
    );
  }
}
