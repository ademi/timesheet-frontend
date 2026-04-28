class ChangePasswordRequestModel {
  const ChangePasswordRequestModel({
    required this.email,
    required this.currentPassword,
    required this.newPassword,
  });

  final String email;
  final String currentPassword;
  final String newPassword;

  Map<String, dynamic> toJson() => {
    'email': email,
    'current_password': currentPassword,
    'new_password': newPassword,
  };
}
