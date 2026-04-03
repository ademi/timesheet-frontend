class VerifyUserRequestModel {
  const VerifyUserRequestModel({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
      };

  factory VerifyUserRequestModel.fromJson(Map<String, dynamic> json) {
    return VerifyUserRequestModel(
      email: json['email'] as String,
      password: json['password'] as String,
    );
  }
}
