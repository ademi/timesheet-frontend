class LogoutResponseModel {
  const LogoutResponseModel({required this.message});

  final String message;

  Map<String, dynamic> toJson() => {
        'message': message,
      };

  factory LogoutResponseModel.fromJson(Map<String, dynamic> json) {
    return LogoutResponseModel(
      message: json['message'] as String? ?? '',
    );
  }
}
