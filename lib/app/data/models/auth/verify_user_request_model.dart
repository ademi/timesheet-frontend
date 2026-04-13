class VerifyUserRequestModel {
  const VerifyUserRequestModel({
    required this.email,
    required this.password,
    required this.token,
  });

  final String email;
  final String password;
  final String token;

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        'token': token,
      };

  factory VerifyUserRequestModel.fromJson(Map<String, dynamic> json) {
    return VerifyUserRequestModel(
      email: json['email'] as String,
      password: json['password'] as String,
      token: json['token'] as String,
    );
  }
}
