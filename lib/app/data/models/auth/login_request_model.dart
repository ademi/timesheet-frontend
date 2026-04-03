class LoginRequestModel {
  const LoginRequestModel({
    required this.email,
    required this.password,
    required this.tenantId,
  });

  final String email;
  final String password;
  final String tenantId;

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        'tenant_id': tenantId,
      };

  factory LoginRequestModel.fromJson(Map<String, dynamic> json) {
    return LoginRequestModel(
      email: json['email'] as String,
      password: json['password'] as String,
      tenantId: json['tenant_id'] as String,
    );
  }
}
