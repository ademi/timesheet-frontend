class VerifyPinResponseModel {
  const VerifyPinResponseModel({
    required this.matched,
    this.pinNotSet = false,
  });

  final bool matched;
  final bool pinNotSet;

  factory VerifyPinResponseModel.fromJson(Map<String, dynamic> json) {
    return VerifyPinResponseModel(
      matched: json['matched'] as bool? ?? false,
      pinNotSet: json['pin_not_set'] as bool? ?? false,
    );
  }
}
