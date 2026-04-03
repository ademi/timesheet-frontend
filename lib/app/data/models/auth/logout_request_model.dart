class LogoutRequestModel {
  const LogoutRequestModel({required this.refreshToken});

  final String refreshToken;

  Map<String, dynamic> toJson() => {
        'refresh_token': refreshToken,
      };

  factory LogoutRequestModel.fromJson(Map<String, dynamic> json) {
    return LogoutRequestModel(
      refreshToken: json['refresh_token'] as String,
    );
  }
}
