class FirstLoginRequestModel {
  const FirstLoginRequestModel({required this.newPassword});

  final String newPassword;

  Map<String, dynamic> toJson() => {'new_password': newPassword};
}
