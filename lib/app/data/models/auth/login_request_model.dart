class LoginRequestModel {
  const LoginRequestModel({
    required this.identifier,
    required this.password,
    this.tenantId,
  });

  final String identifier;
  final String password;
  final String? tenantId;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'identifier': identifier,
      'password': password,
    };
    if (tenantId != null) map['tenant_id'] = tenantId;
    return map;
  }

  factory LoginRequestModel.fromJson(Map<String, dynamic> json) {
    return LoginRequestModel(
      identifier: json['identifier'] as String,
      password: json['password'] as String,
      tenantId: json['tenant_id'] as String?,
    );
  }
}
