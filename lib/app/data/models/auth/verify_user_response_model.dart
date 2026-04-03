class VerifyUserResponseModel {
  const VerifyUserResponseModel({required this.matched});

  final bool matched;

  Map<String, dynamic> toJson() => {
        'matched': matched,
      };

  factory VerifyUserResponseModel.fromJson(Map<String, dynamic> json) {
    final raw = json['matched'];
    final matched = raw is bool
        ? raw
        : raw == true ||
            raw == 1 ||
            (raw is String && raw.toLowerCase() == 'true');
    return VerifyUserResponseModel(matched: matched);
  }
}
