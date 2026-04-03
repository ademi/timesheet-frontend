class AttendanceErrorModel implements Exception {
  const AttendanceErrorModel({required this.detail});

  final String detail;

  @override
  String toString() => detail;

  factory AttendanceErrorModel.fromJson(Map<String, dynamic> json) {
    final raw = json['detail'];
    final message = raw is String
        ? raw
        : raw?.toString() ?? 'Something went wrong';
    return AttendanceErrorModel(detail: message);
  }

  Map<String, dynamic> toJson() => {'detail': detail};
}
