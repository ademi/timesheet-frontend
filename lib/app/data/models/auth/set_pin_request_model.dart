class SetPinRequestModel {
  const SetPinRequestModel({
    required this.email,
    required this.pin,
    required this.confirmPin,
  });

  final String email;
  final String pin;
  final String confirmPin;

  Map<String, dynamic> toJson() => {
        'email': email,
        'pin': pin,
        'confirm_pin': confirmPin,
      };
}
