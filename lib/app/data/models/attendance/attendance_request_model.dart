import '../../../../core/constants/app_constants.dart';

class AttendanceRequestModel {
  const AttendanceRequestModel({
    required this.employeeId,
    required this.lat,
    required this.lng,
    required this.accuracyM,
    this.source = AppConstants.attendanceSource,
  });

  final String employeeId;
  final double lat;
  final double lng;
  final double accuracyM;
  final String source;

  Map<String, dynamic> toJson() => {
        'employee_id': employeeId,
        'lat': lat,
        'lng': lng,
        'accuracy_m': accuracyM,
        'source': source,
      };

  factory AttendanceRequestModel.fromJson(Map<String, dynamic> json) {
    return AttendanceRequestModel(
      employeeId: json['employee_id'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      accuracyM: (json['accuracy_m'] as num).toDouble(),
      source: json['source'] as String? ?? AppConstants.attendanceSource,
    );
  }
}
