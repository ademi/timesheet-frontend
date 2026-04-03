class RefreshRequestModel {
  const RefreshRequestModel({required this.refreshToken});

  final String refreshToken;

  Map<String, dynamic> toJson() => {
        'refresh_token': refreshToken,
      };

  factory RefreshRequestModel.fromJson(Map<String, dynamic> json) {
    return RefreshRequestModel(
      refreshToken: json['refresh_token'] as String,
    );
  }
}
