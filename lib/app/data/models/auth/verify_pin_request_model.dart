class VerifyPinRequestModel {
  const VerifyPinRequestModel({required this.email, required this.pin});

  final String email;
  final String pin;

  Map<String, dynamic> toJson() => {'email': email, 'pin': pin};
}
